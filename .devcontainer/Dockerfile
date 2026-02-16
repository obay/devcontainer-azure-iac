# Azure IaC Development Container
# Base: Ubuntu 24.04 LTS with Azure CLI, OpenTofu, Terraform, kubectl, Helm, and more

FROM ubuntu:24.04

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
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Install Azure CLI via Microsoft apt repository
RUN curl -sLS https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg \
    && chmod 644 /etc/apt/keyrings/microsoft.gpg \
    && echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" \
    > /etc/apt/sources.list.d/azure-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends azure-cli \
    && rm -rf /var/lib/apt/lists/*

# Install Bun (fast package manager and JavaScript runtime)
RUN curl -fsSL https://bun.sh/install | bash \
    && ln -s /root/.bun/bin/bun /usr/local/bin/bun \
    && ln -s /root/.bun/bin/bunx /usr/local/bin/bunx

# Install OpenTofu
ARG OPENTOFU_VERSION=1.10.6
RUN curl -fsSL https://get.opentofu.org/install-opentofu.sh -o install-opentofu.sh \
    && chmod +x install-opentofu.sh \
    && ./install-opentofu.sh --install-method standalone --opentofu-version ${OPENTOFU_VERSION} \
    && rm install-opentofu.sh

# Install Terraform
ARG TERRAFORM_VERSION=1.13.5
RUN curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" -o terraform.zip \
    && unzip -o terraform.zip -d /usr/local/bin \
    && rm terraform.zip \
    && chmod +x /usr/local/bin/terraform

# Install tfren (Terraform file organizer) - https://github.com/obay/tfren
ARG TFREN_VERSION=1.0.4
RUN curl -fsSL "https://github.com/obay/tfren/releases/download/v${TFREN_VERSION}/tfren_Linux_x86_64.tar.gz" \
    | tar -xz -C /usr/local/bin tfren \
    && chmod +x /usr/local/bin/tfren

# Install kubectl
ARG KUBECTL_VERSION=1.32.6
RUN curl -fsSL "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl

# Install Helm
ARG HELM_VERSION=3.17.1
RUN curl -fsSL "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" \
    | tar -xz --strip-components=1 -C /usr/local/bin linux-amd64/helm \
    && chmod +x /usr/local/bin/helm

# Install azcopy (Azure Blob transfer tool)
ARG AZCOPY_VERSION=10.31.1
RUN curl -fsSL "https://github.com/Azure/azure-storage-azcopy/releases/download/v${AZCOPY_VERSION}/azcopy_linux_amd64_${AZCOPY_VERSION}.tar.gz" \
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
RUN curl -fsSL https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb -o packages-microsoft-prod.deb \
    && dpkg -i packages-microsoft-prod.deb \
    && rm packages-microsoft-prod.deb \
    && apt-get update && apt-get install -y --no-install-recommends powershell \
    && rm -rf /var/lib/apt/lists/*

# Install PowerShell modules for Azure and Azure DevOps management
RUN pwsh -NoProfile -Command " \
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted; \
    Install-Module -Name Az -Scope AllUsers -Repository PSGallery; \
    Install-Module -Name VSTeam -Scope AllUsers -Repository PSGallery"

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
