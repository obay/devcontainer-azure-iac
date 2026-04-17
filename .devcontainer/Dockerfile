# Azure IaC Development Container
# Base: Ubuntu 24.04 LTS with Azure CLI, OpenTofu, Terraform, kubectl, Helm, and more

FROM ubuntu:24.04

# Provided automatically by buildx for multi-arch builds (e.g. amd64, arm64)
ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive

# Install system packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    unzip \
    tar \
    git \
    jq \
    vim \
    bash-completion \
    openssh-client \
    skopeo \
    rsync \
    dnsutils \
    gawk \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 22 LTS (required as runtime for Claude Code and devcontainer CLI)
ARG NODE_MAJOR=22
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Azure CLI via Microsoft apt repository
RUN curl -sLS https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg \
    && chmod 644 /etc/apt/keyrings/microsoft.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" \
    > /etc/apt/sources.list.d/azure-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends azure-cli \
    && rm -rf /var/lib/apt/lists/*

# Install Bun (fast package manager and JavaScript runtime)
ENV BUN_INSTALL=/root/.bun
ENV PATH=$BUN_INSTALL/bin:$PATH
RUN curl -fsSL https://bun.sh/install | bash

# Install OpenTofu
ARG OPENTOFU_VERSION=1.10.6
RUN curl -fsSL https://get.opentofu.org/install-opentofu.sh -o install-opentofu.sh \
    && chmod +x install-opentofu.sh \
    && ./install-opentofu.sh --install-method standalone --opentofu-version ${OPENTOFU_VERSION} \
    && rm install-opentofu.sh

# Install Terraform
ARG TERRAFORM_VERSION=1.13.5
RUN curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${TARGETARCH}.zip" -o terraform.zip \
    && unzip -o terraform.zip -d /usr/local/bin \
    && rm terraform.zip \
    && chmod +x /usr/local/bin/terraform

# Install tfren (Terraform file organizer) - https://github.com/obay/tfren
ARG TFREN_VERSION=1.0.4
RUN case "${TARGETARCH}" in \
        amd64) tfren_arch=x86_64 ;; \
        arm64) tfren_arch=arm64 ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
    && curl -fsSL "https://github.com/obay/tfren/releases/download/v${TFREN_VERSION}/tfren_Linux_${tfren_arch}.tar.gz" \
        | tar -xz -C /usr/local/bin tfren \
    && chmod +x /usr/local/bin/tfren

# Install kubectl
ARG KUBECTL_VERSION=1.32.6
RUN curl -fsSL "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl

# Install Helm
ARG HELM_VERSION=3.17.1
RUN curl -fsSL "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${TARGETARCH}.tar.gz" \
    | tar -xz --strip-components=1 -C /usr/local/bin "linux-${TARGETARCH}/helm" \
    && chmod +x /usr/local/bin/helm

# Install azcopy (Azure Blob transfer tool)
ARG AZCOPY_VERSION=10.31.1
RUN curl -fsSL "https://github.com/Azure/azure-storage-azcopy/releases/download/v${AZCOPY_VERSION}/azcopy_linux_${TARGETARCH}_${AZCOPY_VERSION}.tar.gz" \
    | tar -xz --strip-components=1 -C /usr/local/bin --wildcards '*/azcopy' \
    && chmod +x /usr/local/bin/azcopy

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# Install PowerShell
# packages-microsoft-prod.deb hardcodes arch=amd64 in its sources entry, which
# breaks arm64 builds, so we add the prod feed manually with the actual arch.
# The Microsoft GPG key was already installed by the Azure CLI step above.
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/ubuntu/24.04/prod $(lsb_release -cs) main" \
    > /etc/apt/sources.list.d/microsoft-prod.list \
    && apt-get update && apt-get install -y --no-install-recommends powershell \
    && rm -rf /var/lib/apt/lists/*

# Install PowerShell modules for Azure and Azure DevOps management
RUN pwsh -NoProfile -Command " \
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted; \
    Install-Module -Name Az -Scope AllUsers -Repository PSGallery; \
    Install-Module -Name VSTeam -Scope AllUsers -Repository PSGallery"

# Install Claude Code (AI-powered coding assistant)
RUN bun install -g @anthropic-ai/claude-code

# Install Azure CLI extensions (baked into image for reproducibility)
RUN az extension add --name azure-devops \
    && az extension add --name ssh \
    && az extension add --name bastion

# Configure bash completions
RUN echo 'source /etc/bash_completion' >> /root/.bashrc
RUN tofu -install-autocomplete 2>/dev/null || true
RUN echo 'source <(kubectl completion bash)' >> /root/.bashrc
RUN echo 'source <(helm completion bash)' >> /root/.bashrc

# Set working directory
WORKDIR /workspace

# Default command
CMD ["/bin/bash"]
