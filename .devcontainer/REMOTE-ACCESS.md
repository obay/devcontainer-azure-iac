# Remote Access to azure-iac-dev Container

## Overview

The `azure-iac-dev` container provides a pre-configured
environment with Azure CLI, OpenTofu, kubectl, Helm, and
other tools needed to manage Azure infrastructure. It supports a
**dual-container architecture** where a local container and a
remote container run simultaneously.

| Container | Runs on | Purpose |
| --------- | ------- | ------- |
| **Local** | Developer workstation (Mac/Linux) | Entry point for all commands. Runs local Azure/OpenTofu operations and proxies remote commands |
| **Remote** | Network-connected host (Windows) | Runs commands that require access to a private network (AKS clusters, private endpoints) |

## Architecture

```text
Developer Workstation                  Network-Connected Host
  |                                      |
  |  ssh -p 2222 root@localhost          |
  |         |                            |
  |         v                            |
  |  +-------------------+   autossh   +-------------------+
  |  | Local Container   | <---------- | Remote Container  |
  |  |                   |  reverse    |                   |
  |  |  port 2223 <--------  tunnel  ----  port 22         |
  |  |                   |             |                   |
  |  |  `remote` cmd ------  :2223  -->|  kubectl -> AKS   |
  |  |  az, tofu, helm   |             |  az, helm, jq     |
  |  +-------------------+             +-------------------+
  |    Docker (Mac/Linux)                Docker (Windows)
  |    port 2222:22                      port 2222:22
  |
  +-- Workstation never directly exposed
```

The remote container establishes a persistent **reverse SSH
tunnel** (via `autossh`) into the local container. This
creates port 2223 inside the local container, which forwards
to port 22 on the remote container. The developer always
connects to the local container and uses the `remote` command
to execute commands on the remote container when private network
access is needed.

## Quick Start

### Step 1: Start the Local Container

On the developer workstation, use the remote compose overlay:

```bash
cd .devcontainer
docker compose -f docker-compose.yml -f docker-compose.remote.yml up -d
```

### Step 2: Set Up the Remote Container

On the network-connected host, open PowerShell:

```powershell
.\setup-remote-access.ps1 -LocalIP 192.168.0.171 -DevPubKeyFile ~\.ssh\id_rsa.pub
```

The script is **idempotent** and performs these steps:

1. Pulls the latest container image
2. Removes any existing container and starts a fresh one
3. Injects the developer's SSH public key
4. Starts the SSH daemon
5. Generates an ed25519 key pair for the tunnel (first run
   only, persists in Docker volume)
6. Installs the key on the **local container** via
   `ssh-copy-id` (port 2222)
7. Creates the `start-tunnel.sh` helper script

### Step 3: Establish the Reverse Tunnel

On the remote host, start the tunnel inside the remote
container:

```bash
docker exec -it azure-iac-dev bash
start-tunnel.sh
```

The tunnel uses `autossh` for automatic reconnection. It
runs in the background with keepalive enabled.

### Step 4: Connect and Run Commands

From the developer workstation:

```bash
# SSH into the local container
ssh -p 2222 root@localhost

# Run a command locally (inside the local container)
az account show

# Run a command on the remote container (private network)
remote kubectl get pods
remote az account show

# Short alias
r kubectl get nodes
```

Or directly from the terminal without entering the container:

```bash
# Local command
ssh -p 2222 root@localhost "az account show"

# Remote command (via tunnel)
ssh -p 2222 root@localhost "remote kubectl get pods"
```

## Connection Details

| Item | Value |
| ---- | ----- |
| **Local container name** | `azure-iac-dev` |
| **Remote container name** | `azure-iac-dev` |
| **Workstation -> Local SSH** | Port `2222` (mapped to container port 22) |
| **Local -> Remote tunnel** | Port `2223` inside local container (reverse tunnel) |
| **SSH user** | `root` |
| **Authentication** | Public key only (password disabled) |

## The `remote` Command

The `remote` helper script is baked into the Docker image
and available in both containers. It SSHs through the
reverse tunnel on port 2223 using the developer's key
(mounted at `/root/.dev-key`).

```bash
# Interactive shell on the remote container
remote

# Run a single command
remote kubectl get pods

# Run a complex command
remote 'kubectl logs deploy/my-app --tail=50'

# Short alias
r kubectl get nodes
```

## Persistent Volumes

Docker named volumes persist across container rebuilds:

### Local Container

| Volume | Mount Point | Purpose |
| ------ | ----------- | ------- |
| `azure-cli-config` | `/root/.azure` | Azure CLI login state |
| `tofu-plugins` | `/root/.terraform.d/plugin-cache` | OpenTofu provider cache |
| `kube-config` | `/root/.kube` | Kubernetes contexts |
| `ssh-keys` | `/root/.ssh` | SSH keys and authorized_keys |
| Bind mount | `/root/.dev-key` | Developer's RSA key (read-only) |
| Bind mount | `/workspace` | Repository root |

### Remote Container

| Volume | Mount Point | Purpose |
| ------ | ----------- | ------- |
| `azure-iac-dev-azure-cli` | `/root/.azure` | Azure CLI login state |
| `azure-iac-dev-kube-config` | `/root/.kube` | Kubernetes contexts |
| `azure-iac-dev-ssh-keys` | `/root/.ssh` | SSH keys (authorized + tunnel key pair) |

## SSH Key Pairs

Three SSH key pairs are involved:

| Key | Direction | Purpose |
| --- | --------- | ------- |
| Developer's RSA key | Workstation -> Local container | Authenticates the developer to the local container |
| Developer's RSA key | Local -> Remote (via tunnel) | Authenticates `remote` commands (mounted as `/root/.dev-key`) |
| Remote container's ed25519 key | Remote -> Local container | Authenticates the reverse tunnel connection |

## Tunnel Management

The tunnel uses `autossh` with `-M 0` (relies on
`ServerAliveInterval` for monitoring). It automatically
reconnects if the connection drops.

```bash
# Check if tunnel is running (from remote container)
pgrep -f "autossh.*2223"

# Kill the tunnel
pkill -f "autossh.*2223"

# Restart the tunnel
start-tunnel.sh

# Override the target IP
start-tunnel.sh 192.168.0.150
```

## Troubleshooting

| Problem | Solution |
| ------- | -------- |
| `Connection refused` on port 2222 | Is the local container running? (`docker ps`) |
| `Permission denied (publickey)` to local container | Re-run `setup-remote-access.ps1` to re-inject keys |
| `remote` command fails with `Connection refused` | The reverse tunnel is down. On the remote host, restart: `start-tunnel.sh` |
| `remote` command fails with `Permission denied` | The developer's key is not mounted. Check compose has the `/root/.dev-key` bind mount |
| Tunnel drops frequently | `autossh` should auto-reconnect. Check network stability between hosts |
| `kubectl` cannot reach cluster from remote | Azure/AKS credentials may have expired. Inside remote container: `az login` and `az aks get-credentials` |
| Need to check tunnel status | Remote container: `pgrep -f "autossh.*2223"` |

## Rebuilding the Container Image

Both local and remote containers use the same image:

```bash
cd .devcontainer
docker build -t azure-iac-dev:latest .
docker push <your-registry>/azure-iac-dev:latest
```

After pushing:

- **Local**: `docker compose down && docker compose pull && docker compose up -d`
- **Remote**: Re-run `setup-remote-access.ps1` on the remote
  host (pulls the updated image automatically)
