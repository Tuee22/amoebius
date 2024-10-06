# Start from Ubuntu 22.04 base image (multi-arch supported)
FROM ubuntu:22.04

# Define build arguments
ARG TARGETARCH
ARG TARGETOS

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/root/.local/bin:$PATH"

# Update and install base tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    curl \
    wget \
    unzip \
    git \
    tmux \
    htop \
    openssh-client \
    ca-certificates \
    jq \
    lsb-release \
    gnupg \
    tini \
    && rm -rf /var/lib/apt/lists/*

# Add Docker’s official GPG key
RUN mkdir -m 0755 -p /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | tee /etc/apt/keyrings/docker.gpg > /dev/null

# Set up the Docker APT repository
RUN echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
RUN apt-get update && apt-get install -y \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# Copy the entrypoint script
COPY ./docker/start.sh /usr/local/bin/start.sh

# Make sure the entrypoint script is executable
RUN chmod +x /usr/local/bin/start.sh

# Install Terraform
RUN set -eux; \
    cd /tmp; \
    TERRAFORM_VERSION=$(curl -s https://releases.hashicorp.com/terraform/ | grep -o 'terraform/[0-9\.]*/' | head -1 | cut -d'/' -f2); \
    if [ "$TARGETARCH" = "arm64" ]; then \
        TERRAFORM_ARCH="arm64"; \
    else \
        TERRAFORM_ARCH="amd64"; \
    fi; \
    wget -q https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${TERRAFORM_ARCH}.zip; \
    unzip -o terraform_${TERRAFORM_VERSION}_linux_${TERRAFORM_ARCH}.zip; \
    mv terraform /usr/local/bin/; \
    rm terraform_${TERRAFORM_VERSION}_linux_${TERRAFORM_ARCH}.zip

# Install Vault
RUN set -eux; \
    cd /tmp; \
    VAULT_VERSION=$(curl -s https://releases.hashicorp.com/vault/ | grep -o 'vault/[0-9\.]*/' | head -1 | cut -d'/' -f2); \
    if [ "$TARGETARCH" = "arm64" ]; then \
        VAULT_ARCH="arm64"; \
    else \
        VAULT_ARCH="amd64"; \
    fi; \
    wget -q https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_${VAULT_ARCH}.zip; \
    unzip -o vault_${VAULT_VERSION}_linux_${VAULT_ARCH}.zip; \
    mv vault /usr/local/bin/; \
    rm vault_${VAULT_VERSION}_linux_${VAULT_ARCH}.zip

# Install kubectl
RUN if [ "$TARGETARCH" = "arm64" ]; then \
        KUBECTL_ARCH="arm64"; \
    else \
        KUBECTL_ARCH="amd64"; \
    fi; \
    curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/${KUBECTL_ARCH}/kubectl"; \
    chmod +x kubectl && mv kubectl /usr/local/bin/

# Install Helm
RUN set -eux; \
    cd /tmp; \
    HELM_VERSION=$(curl -s https://api.github.com/repos/helm/helm/releases/latest | grep tag_name | cut -d '"' -f4); \
    if [ "$TARGETARCH" = "arm64" ]; then \
        HELM_ARCH="arm64"; \
    else \
        HELM_ARCH="amd64"; \
    fi; \
    wget -q https://get.helm.sh/helm-${HELM_VERSION}-linux-${HELM_ARCH}.tar.gz; \
    tar -zxvf helm-${HELM_VERSION}-linux-${HELM_ARCH}.tar.gz; \
    mv linux-${HELM_ARCH}/helm /usr/local/bin/; \
    rm -rf helm-${HELM_VERSION}-linux-${HELM_ARCH}.tar.gz linux-${HELM_ARCH}

# Install Linkerd
RUN curl -sL https://run.linkerd.io/install | bash && \
    mv /root/.linkerd2/bin/linkerd /usr/local/bin/

# Install RKE
RUN set -eux; \
    cd /tmp; \
    RKE_VERSION=$(curl -s https://api.github.com/repos/rancher/rke/releases/latest | jq -r .tag_name); \
    if [ "$TARGETARCH" = "arm64" ]; then \
        RKE_ARCH="arm64"; \
    else \
        RKE_ARCH="amd64"; \
    fi; \
    curl -L https://github.com/rancher/rke/releases/download/${RKE_VERSION}/rke_linux-${RKE_ARCH} -o /usr/local/bin/rke; \
    chmod +x /usr/local/bin/rke

# Install Python 3.12
RUN add-apt-repository ppa:deadsnakes/ppa -y && \
    apt-get update && apt-get install -y --no-install-recommends \
    python3.12 \
    && rm -rf /var/lib/apt/lists/*

# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/*

# Install Poetry
RUN curl -sSL https://install.python-poetry.org | python3.12 -
# Configure Poetry to not use virtual environments
RUN poetry config virtualenvs.create false

# Install Python packages with semantic versioning
RUN mkdir /app
WORKDIR /app
COPY ./docker/pyproject.toml /app/
RUN poetry install --no-interaction

# Copy the entire amoebius folder to /amoebius
COPY ./ /amoebius

# Use tini as the init system
ENTRYPOINT ["/usr/bin/tini", "--"]

# Start the entrypoint script by default
CMD ["/usr/local/bin/start.sh"]
