#!/usr/bin/env bash
set -euo pipefail

# Ensure the script is run as root (or with sudo)
if [[ "$(id -u)" -ne 0 ]]; then 
  echo "This script must be run as root." >&2
  exit 1
fi

# Default flag values
INSTALL_NVIDIA="false"

# Parse arguments for flags
for arg in "$@"; do
  case "$arg" in
    --install-nvidia)
      INSTALL_NVIDIA="true"
      shift ;;
    *)
      echo "Usage: $0 [--install-nvidia]" >&2
      exit 1 ;;
  esac
done

# Detect architecture (amd64 or arm64)
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *)
    echo "Unsupported architecture: $ARCH" >&2
    exit 1 ;;
esac

# Prevent any interactive prompts during package installation
export DEBIAN_FRONTEND=noninteractive

echo "Updating package index and installing base dependencies..."
apt-get update -y
apt-get install -y --no-install-recommends \
    apt-transport-https ca-certificates curl gnupg lsb-release software-properties-common

# Disable swap (required for Kubernetes) [oai_citation_attribution:0‡docs.pingcap.com](https://docs.pingcap.com/tidb-in-kubernetes/stable/prerequisites/#:~:text=Disable%20swap)
echo "Disabling swap..."
swapoff -a
sed -i.bak '/\sswap\s/s/^/#/' /etc/fstab   # comment out any swap entries to persist after reboot

# Load br_netfilter module for Kubernetes networking and apply sysctl settings
echo "Configuring kernel parameters for Kubernetes..."
modprobe br_netfilter || true
cat > /etc/sysctl.d/90-k8s.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system

# Install Docker (container runtime) [oai_citation_attribution:1‡ranchermanager.docs.rancher.com](https://ranchermanager.docs.rancher.com/how-to-guides/new-user-guides/kubernetes-clusters-in-rancher-setup/node-requirements-for-rancher-managed-clusters#:~:text=All%20supported%20operating%20systems%20are,bit%20x86)
echo "Installing Docker engine..."
# Add Docker’s official GPG key and apt repository for the detected architecture
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=${ARCH} signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list

apt-get update -y
apt-get install -y --no-install-recommends docker-ce docker-ce-cli containerd.io

# Configure Docker cgroup driver to systemd (recommended for Kubernetes) [oai_citation_attribution:2‡elastisys.com](https://elastisys.com/building-and-testing-base-images-for-kubernetes-cluster-nodes-with-packer-qemu-and-chef-inspec/#:~:text=%2A%20%60install,Ubuntu%20Xenial%20releases%20are%20used)
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF

# Enable and start Docker service
systemctl enable docker
systemctl start docker

# Optional: NVIDIA driver and container toolkit installation
if [[ "$INSTALL_NVIDIA" == "true" ]]; then
  echo "NVIDIA installation flag detected. Installing NVIDIA driver and container toolkit..."
  if [[ "$ARCH" == "amd64" ]]; then
    # Add graphics drivers PPA for latest NVIDIA driver (if not already available)
    add-apt-repository -y ppa:graphics-drivers/ppa || true
    apt-get update -y
    # Install NVIDIA driver (version 570) – ensures GPU support on the node
    apt-get install -y --no-install-recommends nvidia-driver-570
  else
    echo "NVIDIA drivers are not automatically installed on architecture $ARCH; skipping driver installation."
  fi
  # Install NVIDIA Container Toolkit (for GPU-accelerated containers) [oai_citation_attribution:3‡docs.nvidia.com](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html#:~:text=3,Toolkit%20packages)
  distribution=$(. /etc/os-release; echo "${ID}${VERSION_ID}")
  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
      gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
  curl -s -L "https://nvidia.github.io/libnvidia-container/stable/${distribution}/$(dpkg --print-architecture)/nvidia-container-toolkit.list" | \
      sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
      > /etc/apt/sources.list.d/nvidia-container-toolkit.list

  apt-get update -y
  apt-get install -y --no-install-recommends nvidia-container-toolkit
  # Restart Docker to load the new NVIDIA toolkit runtime
  systemctl restart docker
fi

# Clean up apt cache to minimize image size (if creating a VM image)
apt-get autoremove -y
apt-get clean

echo "Setup complete. The system will reboot now to finalize configuration."
sleep 5
reboot