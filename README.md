# devcontainer-azure-iac

[![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04_LTS-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![Azure CLI](https://img.shields.io/badge/Azure_CLI-latest-0078D4?logo=microsoftazure&logoColor=white)](https://learn.microsoft.com/en-us/cli/azure/)
[![OpenTofu](https://img.shields.io/badge/OpenTofu-1.10.6-FFDA18?logo=opentofu&logoColor=black)](https://opentofu.org/)
[![Terraform](https://img.shields.io/badge/Terraform-1.13.5-844FBA?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Kubernetes](https://img.shields.io/badge/kubectl-1.32.6-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![Helm](https://img.shields.io/badge/Helm-3.17.1-0F1689?logo=helm&logoColor=white)](https://helm.sh/)
[![GitHub CLI](https://img.shields.io/badge/GitHub_CLI-latest-181717?logo=github&logoColor=white)](https://cli.github.com/)
[![Docker](https://img.shields.io/badge/Dev_Container-ready-2496ED?logo=docker&logoColor=white)](https://containers.dev/)
[![Bun](https://img.shields.io/badge/Bun-latest-F9F1E1?logo=bun&logoColor=black)](https://bun.sh/)
[![PowerShell](https://img.shields.io/badge/PowerShell-latest-5391FE?logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Claude Code](https://img.shields.io/badge/Claude_Code-latest-D97757?logo=anthropic&logoColor=white)](https://docs.anthropic.com/en/docs/claude-code)

A pre-built development container for Azure Infrastructure as Code projects. Includes Azure CLI, OpenTofu, Terraform, kubectl, Helm, PowerShell, Claude Code, and other tools for managing Azure infrastructure.

## What's Included

| Tool        | Version    | Purpose                                 |
| ----------- | ---------- | --------------------------------------- |
| Azure CLI   | latest     | Azure resource management               |
| OpenTofu    | 1.10.6     | Open-source Terraform alternative       |
| Terraform   | 1.13.5     | Infrastructure as Code                  |
| tfren       | 1.0.4      | Terraform file organizer                |
| kubectl     | 1.32.6     | Kubernetes cluster management           |
| Helm        | 3.17.1     | Kubernetes package manager              |
| azcopy      | 10.31.1    | Azure Blob transfer tool                |
| GitHub CLI  | latest     | GitHub from the command line            |
| Bun         | latest     | JavaScript runtime and package manager  |
| PowerShell  | latest     | Cross-platform automation and scripting |
| Claude Code | latest     | AI-powered coding assistant             |
| Node.js     | OS package | JavaScript runtime                      |

Azure CLI extensions: `azure-devops`, `ssh`, `bastion`

PowerShell modules: `Az` (Azure management), `VSTeam` (Azure DevOps management)

## Quick Start

Create a `.env` file with your credentials (see [.env.template](.devcontainer/.env.template) for the full list):

```ini
# Required
ARM_TENANT_ID=<your-tenant-id>
ARM_SUBSCRIPTION_ID=<your-subscription-id>
ARM_CLIENT_ID=<your-client-id>
ARM_CLIENT_SECRET=<your-client-secret>

# Optional — only if you use Azure DevOps
AZURE_DEVOPS_EXT_PAT=<your-personal-access-token>
AZURE_DEVOPS_ORG_URL=<https://dev.azure.com/your-org>

# Optional — only if you use GitHub
GH_TOKEN=<your-github-personal-access-token>

# Optional — only if you use Claude Code
ANTHROPIC_API_KEY=<your-anthropic-api-key>
```

Then pull the image and start a container:

**Mac / Linux:**

```bash
docker run -dit \
  --name azure-iac-dev \
  --env-file .env \
  -v "$(pwd)":/workspace \
  -v azure-cli-config:/root/.azure \
  -v tofu-plugins:/root/.terraform.d/plugin-cache \
  -v kube-config:/root/.kube \
  -v ~/.claude:/root/.claude \
  xobay/azure-iac-dev:latest
```

**Windows (PowerShell):**

```powershell
docker run -dit `
  --name azure-iac-dev `
  --env-file .env `
  -v "${PWD}:/workspace" `
  -v azure-cli-config:/root/.azure `
  -v tofu-plugins:/root/.terraform.d/plugin-cache `
  -v kube-config:/root/.kube `
  -v "$env:USERPROFILE\.claude:/root/.claude" `
  xobay/azure-iac-dev:latest
```

Open a shell inside the container:

```bash
docker exec -it azure-iac-dev bash
```

## Environment Variables

### Required

| Variable              | Description                               |
| --------------------- | ----------------------------------------- |
| `ARM_TENANT_ID`       | Azure AD tenant ID                        |
| `ARM_SUBSCRIPTION_ID` | Target Azure subscription ID              |
| `ARM_CLIENT_ID`       | Service principal application (client) ID |
| `ARM_CLIENT_SECRET`   | Service principal secret                  |

### Optional

| Variable               | Description                                                        |
| ---------------------- | ------------------------------------------------------------------ |
| `AZURE_DEVOPS_EXT_PAT` | Azure DevOps personal access token                                 |
| `AZURE_DEVOPS_ORG_URL` | Azure DevOps organisation URL (e.g. `https://dev.azure.com/myorg`) |
| `GH_TOKEN`             | GitHub personal access token for `gh` CLI                          |
| `ANTHROPIC_API_KEY`    | Anthropic API key for Claude Code                                  |

### Set automatically inside the container

| Variable              | Value                             | Purpose                                           |
| --------------------- | --------------------------------- | ------------------------------------------------- |
| `TF_PLUGIN_CACHE_DIR` | `/root/.terraform.d/plugin-cache` | Cache Terraform/OpenTofu providers across runs    |
| `TF_INPUT`            | `0`                               | Disable interactive prompts in Terraform/OpenTofu |
| `KUBECONFIG`          | `/root/.kube/config`              | Kubernetes configuration path                     |

## Usage

### Authenticate to Azure

```bash
az login --service-principal \
  -u $ARM_CLIENT_ID \
  -p $ARM_CLIENT_SECRET \
  -t $ARM_TENANT_ID

az account set --subscription $ARM_SUBSCRIPTION_ID

# Verify
az account show
```

### Terraform / OpenTofu

```bash
tofu init
tofu plan
tofu apply

# Same commands work with terraform
terraform init
terraform plan
terraform apply
```

### Kubernetes (AKS)

```bash
# Get credentials for an AKS cluster
az aks get-credentials --resource-group <rg-name> --name <cluster-name>

# Verify connectivity
kubectl get nodes
kubectl get pods --all-namespaces
```

### Helm

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install my-release bitnami/nginx
```

### PowerShell (Azure & Azure DevOps)

```powershell
# Start a PowerShell session
pwsh

# Authenticate to Azure
Connect-AzAccount -ServicePrincipal `
  -TenantId $env:ARM_TENANT_ID `
  -ApplicationId $env:ARM_CLIENT_ID `
  -CertificateThumbprint $env:ARM_CLIENT_SECRET
# Or use a credential object
$cred = New-Object PSCredential($env:ARM_CLIENT_ID, (ConvertTo-SecureString $env:ARM_CLIENT_SECRET -AsPlainText -Force))
Connect-AzAccount -ServicePrincipal -TenantId $env:ARM_TENANT_ID -Credential $cred

# Manage Azure resources
Get-AzResourceGroup
Get-AzVM

# Connect to Azure DevOps (VSTeam)
Set-VSTeamAccount -Account $env:AZURE_DEVOPS_ORG_URL -PersonalAccessToken $env:AZURE_DEVOPS_EXT_PAT
Get-VSTeamProject
Get-VSTeamBuildDefinition -ProjectName <project-name>
```

### Claude Code

```bash
# Your host login session is shared via the ~/.claude mount — no extra auth needed
claude

# Non-interactive usage
claude -p "explain this terraform module"

# Or authenticate with an API key (via ANTHROPIC_API_KEY in .env)
```

### GitHub CLI

```bash
# GH_TOKEN is picked up automatically from the environment
gh auth status

# Common operations
gh repo list
gh pr list
gh issue list
```

## Persistent Data

Named Docker volumes persist across container rebuilds:

| Volume             | Mount point                       | Purpose                                 |
| ------------------ | --------------------------------- | --------------------------------------- |
| `azure-cli-config` | `/root/.azure`                    | Azure CLI login state and configuration |
| `tofu-plugins`     | `/root/.terraform.d/plugin-cache` | Terraform/OpenTofu provider cache       |
| `kube-config`      | `/root/.kube`                     | Kubernetes contexts and credentials     |
| `~/.claude` (bind) | `/root/.claude`                   | Claude Code login, settings, and memory |

## Building from Source

If you want to customise the image or use the VS Code Dev Container workflow:

1. Clone this repo or copy the `.devcontainer/` folder into your project

2. Create your credentials file:

   **Mac / Linux:**

   ```bash
   cp .devcontainer/.env.template .devcontainer/.env
   ```

   **Windows (PowerShell):**

   ```powershell
   Copy-Item .devcontainer\.env.template .devcontainer\.env
   ```

   Edit `.env` with your Azure credentials.

3. Open in VS Code and select **Reopen in Container**, or start manually:

   ```bash
   cd .devcontainer && docker compose up -d
   ```

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
