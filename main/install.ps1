# ==============================
# WSL Automated Setup Script
# ==============================

$SCRIPT_PATH = $MyInvocation.MyCommand.Path
$TASK_NAME = "AutoStartWSL"

Write-Host "=== WSL Setup Started ===" -ForegroundColor Green

# ------------------------------
# 1. Enable required Windows features
# ------------------------------
Write-Host "Enabling WSL and Virtual Machine Platform..."
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

# ------------------------------
# 2. Set WSL 2 as default
# ------------------------------
wsl --set-default-version 2

# ------------------------------
# 3. Install Ubuntu if missing
# ------------------------------
$distros = wsl -l -q 2>$null
if ($distros -notcontains "Ubuntu") {
    Write-Host "Installing Ubuntu..."
    wsl --install -d Ubuntu
    Write-Host "Ubuntu installed. Please RESTART Windows and re-run this script."
    exit 0
}

# ------------------------------
# 4. Ask Linux username & password
# ------------------------------
$LINUX_USER = Read-Host "Enter Linux username"

$PASSWORD_SECURE = Read-Host "Enter Linux password" -AsSecureString
$PASSWORD_PLAIN = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($PASSWORD_SECURE)
)

# ------------------------------
# 5. Create Linux user
# ------------------------------
Write-Host "Creating Linux user..."

wsl -d Ubuntu -- bash -c "
id $LINUX_USER >/dev/null 2>&1 || (
    useradd -m -s /bin/bash $LINUX_USER &&
    echo '$LINUX_USER:$PASSWORD_PLAIN' | chpasswd &&
    usermod -aG sudo $LINUX_USER
)
"

# ------------------------------
# 6. Set default WSL user
# ------------------------------
wsl -d Ubuntu -- bash -c "
tee /etc/wsl.conf >/dev/null <<EOF
[user]
default=$LINUX_USER
EOF
"

# ------------------------------
# 7. Register Windows startup task
# ------------------------------
Write-Host "Registering Windows startup task..."

schtasks /create `
 /tn $TASK_NAME `
 /tr "wsl.exe -d Ubuntu -- echo 'WSL started'" `
 /sc onstart `
 /ru SYSTEM `
 /rl HIGHEST `
 /f

# ------------------------------
# 8. Restart WSL
# ------------------------------
wsl --shutdown

Write-Host "=== WSL Setup Completed Successfully ===" -ForegroundColor Green
Write-Host "WSL will now start automatically on every Windows boot"
Write-Host "Default Linux user: $LINUX_USER"
