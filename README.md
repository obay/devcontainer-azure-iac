# devcontainer-azure-iac

[![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04_LTS-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![Azure CLI](https://img.shields.io/badge/Azure_CLI-latest-0078D4?logo=microsoftazure&logoColor=white)](https://learn.microsoft.com/en-us/cli/azure/)
[![OpenTofu](https://img.shields.io/badge/OpenTofu-1.10.6-FFDA18?logo=opentofu&logoColor=black)](https://opentofu.org/)
[![Terraform](https://img.shields.io/badge/Terraform-1.13.5-844FBA?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Kubernetes](https://img.shields.io/badge/kubectl-1.32.6-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![Helm](https://img.shields.io/badge/Helm-3.17.1-0F1689?logo=helm&logoColor=white)](https://helm.sh/)
[![Docker](https://img.shields.io/badge/Dev_Container-ready-2496ED?logo=docker&logoColor=white)](https://containers.dev/)
[![Bun](https://img.shields.io/badge/Bun-latest-F9F1E1?logo=bun&logoColor=black)](https://bun.sh/)

A generic, reusable development container for Azure Infrastructure as Code projects. Pre-configured with the tools you need for Terraform/OpenTofu, Kubernetes, and Azure management.

## What's Included

| Tool | Version | Purpose |
| ---- | ------- | ------- |
| Azure CLI | latest | Azure resource management |
| OpenTofu | 1.10.6 | Open-source Terraform alternative |
| Terraform | 1.13.5 | Infrastructure as Code |
| tfren | 1.0.4 | Terraform file organizer |
| kubectl | 1.32.6 | Kubernetes cluster management |
| Helm | 3.17.1 | Kubernetes package manager |
| azcopy | 10.31.1 | Azure Blob transfer tool |
| Bun | latest | JavaScript runtime and package manager |
| Node.js | OS package | JavaScript runtime |

Azure CLI extensions: `azure-devops`, `ssh`, `bastion`

All tool versions are configurable via Docker build args (e.g. `--build-arg TERRAFORM_VERSION=1.14.0`).

## Quick Start

1. Copy the `.devcontainer/` folder into your project (or clone this repo)

2. Create your credentials file:

   ```bash
   cp .devcontainer/.env.template .devcontainer/.env
   # Edit .env with your Azure credentials
   ```

3. Open the project in VS Code and select **Reopen in Container**, or start manually:

   ```bash
   cd .devcontainer && docker compose up -d
   ```

4. Log in to Azure:

   ```bash
   az login --service-principal -u $ARM_CLIENT_ID -p $ARM_CLIENT_SECRET -t $ARM_TENANT_ID
   ```

## Persistent Data

Named Docker volumes persist across container rebuilds:

- `/root/.azure` — Azure CLI login state
- `/root/.terraform.d/plugin-cache` — OpenTofu/Terraform provider cache
- `/root/.kube` — Kubernetes contexts and credentials
- `/root/.ssh` — SSH keys

## Remote Access (Optional)

For scenarios where you develop locally but need access to a private network (e.g. on-prem AKS clusters), this project includes a dual-container SSH tunnel architecture.

To enable remote access, use the compose overlay:

```bash
cd .devcontainer
docker compose -f docker-compose.yml -f docker-compose.remote.yml up -d
```

This exposes SSH on port 2222 and mounts your local SSH key for the `remote` command. See [REMOTE-ACCESS.md](.devcontainer/REMOTE-ACCESS.md) for the full setup guide.

## Customisation

### Adding tools

Edit [.devcontainer/Dockerfile](.devcontainer/Dockerfile) and add `RUN` instructions.

### Changing tool versions

Override build args in `docker-compose.yml`:

```yaml
services:
  azure-iac-dev:
    build:
      args:
        TERRAFORM_VERSION: "1.14.0"
        KUBECTL_VERSION: "1.33.0"
```

Or pass them directly:

```bash
docker compose build --build-arg TERRAFORM_VERSION=1.14.0
```

### Adding VS Code extensions

Edit the `extensions` array in [.devcontainer/devcontainer.json](.devcontainer/devcontainer.json).

### Adding environment variables

Add variables to [.devcontainer/.env.template](.devcontainer/.env.template) and reference them in the `environment` section of [.devcontainer/docker-compose.yml](.devcontainer/docker-compose.yml).
