# =============================================================================
# Setup Remote SSH Access to azure-iac-dev Container
# =============================================================================
# Run this script on the network-connected host (Windows) to pull the container
# from Docker Hub, configure SSH access, and prepare a reverse tunnel back
# to the developer's local workstation.
#
# The script is idempotent: running it again will tear down and recreate the
# container from scratch. The SSH key pair is preserved in a Docker named
# volume and is only generated on the very first run.
#
# Prerequisites:
#   - Docker Desktop for Windows (WSL 2 backend)
#   - Network connectivity to the target private network
#   - Docker Hub login (if using a private image)
#   - .env file alongside this script (see .env.template)
#
# Usage:
#   .\setup-remote-access.ps1 -LocalIP 192.168.0.171 -DevPubKeyFile ~\.ssh\id_rsa.pub
#   .\setup-remote-access.ps1 -LocalIP 192.168.0.171 -DevPubKeyFile ~\.ssh\id_rsa.pub -SkipTunnel
#   .\setup-remote-access.ps1 -LocalIP 192.168.0.171 -DevPubKeyFile ~\.ssh\id_rsa.pub -ImageName myregistry/azure-iac-dev:latest
#
# After running:
#   1. Inside the container, run: start-tunnel.sh
#   2. On the local workstation: ssh -p 2222 root@localhost
# =============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$LocalIP,

    [Parameter(Mandatory=$true)]
    [string]$DevPubKeyFile,

    [string]$LocalUser     = $env:USERNAME,
    [string]$ContainerName = "azure-iac-dev",
    [string]$ImageName     = "azure-iac-dev:latest",
    [switch]$SkipTunnel
)

$ErrorActionPreference = "Stop"

# Read the developer's public key
if (-not (Test-Path $DevPubKeyFile)) {
    Write-Host "ERROR: SSH public key file not found: $DevPubKeyFile" -ForegroundColor Red
    exit 1
}
$DevPubKey = (Get-Content $DevPubKeyFile -Raw).Trim()

Write-Host "=== Setting up remote container ===" -ForegroundColor Cyan
Write-Host "  Local workstation: $LocalUser@$LocalIP"
Write-Host "  Container:         $ContainerName"
Write-Host "  Image:             $ImageName"
Write-Host ""

# -----------------------------------------------------------------------
# Step 1: Check Docker is running
# -----------------------------------------------------------------------
Write-Host "Step 1: Checking Docker..." -ForegroundColor Yellow
try {
    docker info | Out-Null
} catch {
    Write-Host "ERROR: Docker is not running. Start Docker Desktop first." -ForegroundColor Red
    exit 1
}

# -----------------------------------------------------------------------
# Step 2: Stop and remove existing container (idempotent)
# -----------------------------------------------------------------------
Write-Host "Step 2: Cleaning up existing container..." -ForegroundColor Yellow
docker stop $ContainerName 2>$null
docker rm $ContainerName 2>$null

# -----------------------------------------------------------------------
# Step 3: Pull the latest image from Docker Hub
# -----------------------------------------------------------------------
Write-Host "Step 3: Pulling image..." -ForegroundColor Yellow
docker pull $ImageName
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to pull image. Check your Docker login and image name." -ForegroundColor Red
    exit 1
}

# -----------------------------------------------------------------------
# Step 4: Verify .env file
# -----------------------------------------------------------------------
Write-Host "Step 4: Checking prerequisites..." -ForegroundColor Yellow
$EnvFile = Join-Path $PSScriptRoot ".env"
if (-not (Test-Path $EnvFile)) {
    Write-Host "ERROR: .env file not found at $EnvFile" -ForegroundColor Red
    Write-Host "Place .env alongside this script with ARM_TENANT_ID, ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_SUBSCRIPTION_ID" -ForegroundColor Yellow
    exit 1
}

# -----------------------------------------------------------------------
# Step 5: Start the container
# -----------------------------------------------------------------------
Write-Host "Step 5: Starting container..." -ForegroundColor Yellow
docker run -dit `
    --name $ContainerName `
    -p 2222:22 `
    -v "${ContainerName}-azure-cli:/root/.azure" `
    -v "${ContainerName}-kube-config:/root/.kube" `
    -v "${ContainerName}-ssh-keys:/root/.ssh" `
    --env-file $EnvFile `
    -e KUBECONFIG=/root/.kube/config `
    $ImageName

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to start container." -ForegroundColor Red
    exit 1
}

Write-Host "  Waiting for container to be ready..."
Start-Sleep -Seconds 5

# -----------------------------------------------------------------------
# Step 6: Inject developer's public key into container authorized_keys
# -----------------------------------------------------------------------
Write-Host "Step 6: Injecting developer SSH public key..." -ForegroundColor Yellow
$TempKeyFile = [System.IO.Path]::GetTempFileName()
Set-Content -Path $TempKeyFile -Value $DevPubKey -NoNewline
docker exec $ContainerName bash -c "mkdir -p /root/.ssh && chmod 700 /root/.ssh"
docker cp $TempKeyFile "${ContainerName}:/root/.ssh/authorized_keys"
docker exec $ContainerName chmod 600 /root/.ssh/authorized_keys
Remove-Item $TempKeyFile -Force
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to inject SSH key." -ForegroundColor Red
    exit 1
}

# -----------------------------------------------------------------------
# Step 7: Start SSH daemon
# -----------------------------------------------------------------------
Write-Host "Step 7: Starting SSH daemon..." -ForegroundColor Yellow
docker exec $ContainerName bash -c "pkill sshd 2>/dev/null; sleep 1; /usr/sbin/sshd"

Write-Host "  Verifying SSH configuration..."
docker exec $ContainerName /usr/sbin/sshd -T 2>&1 | Select-String -Pattern "permitrootlogin|pubkeyauthentication|passwordauthentication"

# -----------------------------------------------------------------------
# Step 8: Generate SSH key pair for reverse tunnel (if not in volume)
# -----------------------------------------------------------------------
Write-Host "Step 8: Preparing reverse tunnel key pair..." -ForegroundColor Yellow
$KeyExists = docker exec $ContainerName bash -c "test -f /root/.ssh/id_ed25519 && echo yes || echo no"
if ($KeyExists.Trim() -eq "no") {
    Write-Host "  Generating new ed25519 key pair..."
    docker exec $ContainerName ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N '""' -C "${ContainerName}-container"
} else {
    Write-Host "  Key pair already exists in volume (reusing)"
}

# -----------------------------------------------------------------------
# Step 9: Install container's public key on the local container
# -----------------------------------------------------------------------
if (-not $SkipTunnel) {
    Write-Host "Step 9: Installing container key on local container ($LocalIP:2222)..." -ForegroundColor Yellow
    Write-Host "  The local container must be running on the developer workstation."
    Write-Host "  If this is the first run, you will be prompted for the"
    Write-Host "  container root password (should use key auth)."
    Write-Host ""
    docker exec -it $ContainerName ssh-copy-id -i /root/.ssh/id_ed25519.pub -p 2222 -o StrictHostKeyChecking=accept-new "root@${LocalIP}"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "WARNING: ssh-copy-id failed. The reverse tunnel may not work." -ForegroundColor Yellow
        Write-Host "  Ensure the local container is running on the developer workstation." -ForegroundColor Yellow
        Write-Host "  Run: cd .devcontainer && docker compose -f docker-compose.yml -f docker-compose.remote.yml up -d" -ForegroundColor Yellow
    } else {
        Write-Host "  Key installed successfully." -ForegroundColor Green
    }
}

# -----------------------------------------------------------------------
# Step 10: Create start-tunnel.sh helper inside the container
# -----------------------------------------------------------------------
Write-Host "Step 10: Creating tunnel helper script..." -ForegroundColor Yellow

$TunnelScript = @"
#!/bin/bash
# Establish a persistent reverse SSH tunnel to the local container
# on the developer's workstation. Uses autossh for auto-reconnection.
#
# The tunnel binds port 2223 inside the local container, forwarding
# connections back to this (remote) container's SSH on port 22.
#
# Usage:
#   start-tunnel.sh                       # use defaults
#   start-tunnel.sh 192.168.0.171         # override IP

LOCAL_IP=`${1:-$LocalIP}

# Check if tunnel is already running
if pgrep -f "autossh.*2223:localhost:22" > /dev/null 2>&1; then
    echo "Reverse tunnel is already running."
    echo "To restart: pkill -f 'autossh.*2223' && start-tunnel.sh"
    exit 0
fi

echo "Establishing persistent reverse tunnel to local container at `$LOCAL_IP:2222..."
export AUTOSSH_GATETIME=0
autossh -M 0 -N -f \
    -R 2223:localhost:22 \
    -p 2222 \
    -o StrictHostKeyChecking=accept-new \
    -o ServerAliveInterval=60 \
    -o ServerAliveCountMax=3 \
    -o ExitOnForwardFailure=yes \
    "root@`$LOCAL_IP"

if [ `$? -eq 0 ]; then
    echo ""
    echo "Tunnel established successfully."
    echo "From the local container, run commands on this remote container with:"
    echo ""
    echo "  remote kubectl get pods"
    echo "  remote az account show"
    echo ""
else
    echo ""
    echo "ERROR: Failed to establish tunnel."
    echo "Check that:"
    echo "  1. The local container is running on the developer workstation"
    echo "  2. This container's ed25519 key is in the local container's authorized_keys"
    echo "  3. The workstation is reachable at `$LOCAL_IP"
    echo "  4. Port 2222 is open on the workstation (local container SSH)"
    exit 1
fi
"@

$TempScript = [System.IO.Path]::GetTempFileName()
Set-Content -Path $TempScript -Value $TunnelScript -NoNewline
docker cp $TempScript "${ContainerName}:/usr/local/bin/start-tunnel.sh"
docker exec $ContainerName chmod +x /usr/local/bin/start-tunnel.sh
Remove-Item $TempScript -Force

# -----------------------------------------------------------------------
# Step 11: Display connection instructions
# -----------------------------------------------------------------------
Write-Host "`n=== Setup Complete ===" -ForegroundColor Green
Write-Host ""

Write-Host "Host IP addresses:" -ForegroundColor Cyan
$IPs = Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -ne "127.0.0.1" -and $_.PrefixOrigin -ne "WellKnown" } |
    Select-Object IPAddress, InterfaceAlias
foreach ($ip in $IPs) {
    Write-Host "  $($ip.IPAddress)  ($($ip.InterfaceAlias))"
}

Write-Host ""
Write-Host "--- Two-Container Architecture ---" -ForegroundColor Cyan
Write-Host "  Both local and remote containers run simultaneously." -ForegroundColor White
Write-Host "  The remote container tunnels into the local container." -ForegroundColor White
Write-Host ""
Write-Host "  1. Ensure local container is running on the developer workstation:" -ForegroundColor White
Write-Host "       cd .devcontainer && docker compose -f docker-compose.yml -f docker-compose.remote.yml up -d" -ForegroundColor White
Write-Host ""
Write-Host "  2. Start the reverse tunnel from this (remote) container:" -ForegroundColor White
Write-Host "       docker exec -it $ContainerName bash" -ForegroundColor White
Write-Host "       start-tunnel.sh" -ForegroundColor White
Write-Host ""
Write-Host "  3. On the developer workstation, connect to the local container:" -ForegroundColor White
Write-Host "       ssh -p 2222 root@localhost" -ForegroundColor White
Write-Host ""
Write-Host "  4. From the local container, run commands on the remote container:" -ForegroundColor White
Write-Host "       remote kubectl get pods" -ForegroundColor White
Write-Host "       remote az account show" -ForegroundColor White
Write-Host ""
