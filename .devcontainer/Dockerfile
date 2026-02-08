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
    openssh-server \
    skopeo \
    rsync \
    dnsutils \
    gawk \
    autossh \
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

# Install Azure CLI extensions (baked into image for reproducibility)
RUN az extension add --name azure-devops \
    && az extension add --name ssh \
    && az extension add --name bastion

# Configure SSH server for remote access
RUN mkdir -p /var/run/sshd \
    && ssh-keygen -A \
    && mkdir -p /root/.ssh \
    && chmod 700 /root/.ssh \
    && sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config \
    && sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/^#*AuthorizedKeysFile.*/AuthorizedKeysFile .ssh\/authorized_keys/' /etc/ssh/sshd_config

# Configure bash completions
RUN echo 'source /etc/bash_completion' >> /root/.bashrc
RUN tofu -install-autocomplete 2>/dev/null || true
RUN echo 'source <(kubectl completion bash)' >> /root/.bashrc
RUN echo 'source <(helm completion bash)' >> /root/.bashrc

# Helper script to execute commands on the remote container via SSH tunnel
RUN printf '#!/bin/bash\n\
# Execute a command on the remote container via reverse SSH tunnel (port 2223)\n\
# Usage: remote <command>        (run command on remote)\n\
#        remote                  (interactive shell on remote)\n\
if [ $# -eq 0 ]; then\n\
  exec ssh -p 2223 -i /root/.dev-key -o StrictHostKeyChecking=no -o LogLevel=ERROR root@localhost\n\
else\n\
  exec ssh -p 2223 -i /root/.dev-key -o StrictHostKeyChecking=no -o LogLevel=ERROR root@localhost "$@"\n\
fi\n' > /usr/local/bin/remote && chmod +x /usr/local/bin/remote
RUN echo 'alias r=remote' >> /root/.bashrc

# Expose SSH port
EXPOSE 22

# Set working directory
WORKDIR /workspace

# Start SSH daemon on container startup via bashrc (works with interactive TTY)
RUN echo '/usr/sbin/sshd 2>/dev/null' >> /root/.bashrc

# Default command
CMD ["/bin/bash"]
