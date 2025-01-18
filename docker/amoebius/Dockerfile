# Start from Ubuntu 22.04 base image (multi-arch supported)
FROM ubuntu:22.04

# Define build arguments
ARG TARGETARCH
ARG TARGETOS

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/root/.local/bin:/usr/local/bin:$PATH"

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
    gnupg \
    nano \
    tini \
    bash-completion \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y wget && \
    wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq && \
    chmod +x /usr/bin/yq && \
    apt-get clean

# Add Docker’s official GPG key manually using curl and store it in /usr/share/keyrings
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Set up the Docker repository with the correct GPG key reference
RUN echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine and plugins
RUN apt-get update && apt-get install -y \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

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

# Add kubectl completion
RUN echo "source /usr/share/bash-completion/bash_completion" >> /root/.bashrc && \
    echo "source <(kubectl completion bash)" >> /root/.bashrc

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

# Install Kind
RUN set -eux; \
    cd /tmp; \
    KIND_VERSION=$(curl -s https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")'); \
    if [ "$TARGETARCH" = "arm64" ]; then \
        KIND_ARCH="arm64"; \
    else \
        KIND_ARCH="amd64"; \
    fi; \
    wget -q https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-${KIND_ARCH}; \
    chmod +x kind-linux-${KIND_ARCH}; \
    mv kind-linux-${KIND_ARCH} /usr/local/bin/kind

# install helm repos
RUN helm repo add hashicorp https://helm.releases.hashicorp.com

# Install Python 3.12
RUN add-apt-repository ppa:deadsnakes/ppa -y && \
    apt-get update && apt-get install -y --no-install-recommends \
    python3.12-venv \
    python3.12-dev \
    python3.12-lib2to3 \
    && rm -rf /var/lib/apt/lists/*

# Set Python 3.12 as the default python3 and python versions
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1 && \
    update-alternatives --set python3 /usr/bin/python3.12 && \
    update-alternatives --install /usr/bin/python python /usr/bin/python3.12 1 && \
    update-alternatives --set python /usr/bin/python3.12

# Install pip for Python 3.12
RUN curl -sS https://bootstrap.pypa.io/get-pip.py | python3.12

# Upgrade pip, setuptools, and wheel
RUN python -m pip install --upgrade pip setuptools wheel

# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/*

# Install Poetry
RUN curl -sSL https://install.python-poetry.org | python3.12 -
# Configure Poetry to not use virtual environments
RUN poetry config virtualenvs.create false

# Install Python packages with semantic versioning
RUN mkdir /poetry
WORKDIR /poetry
COPY ./docker/amoebius/pyproject.toml /poetry/
RUN poetry install --no-interaction --no-root

# Copy the entire amoebius folder to /amoebius
COPY ./ /amoebius
WORKDIR /amoebius
ENV PYTHONPATH="/amoebius/python"

# validate code with mypy
RUN mypy /amoebius/python --strict --no-incremental && rm -rf .mypy_cache

EXPOSE 8080

# Use tini as the init system (reaps zombie processes)
ENTRYPOINT ["/usr/bin/tini", "--"]

# Run the daemon inside the package
CMD ["python", "-m", "amoebius.daemon"]