# =========================================================
# WSL Installer – Phase-split, Parameter-free
#
# DESIGN PRINCIPLES:
# 1. Script is always started by STANDARD USER
# 2. Admin rights are used ONLY to enable system-wide WSL features
# 3. WSL distro + tasks are ALWAYS created as STANDARD USER
# 4. Phase-2 must NEVER run in admin context (hard enforced)
#
# DO NOT move Phase-2 code above the admin guard.
# =========================================================

# ------------------------------
# Globals
# ------------------------------
$DISTRO     = "Ubuntu"
$TASK_NAME  = "WSL-PostBoot"
$SCRIPT     = $PSCommandPath

# ------------------------------
# Logging
# ------------------------------
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO","WARN","ERROR")]
        [string]$Level = "INFO"
    )

    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

    $color = switch ($Level) {
        "INFO"  { "Gray" }
        "WARN"  { "Yellow" }
        "ERROR" { "Red" }
    }

    Write-Host "$ts [$env:USERNAME] [$Level] $Message" -ForegroundColor $color
}

$STATE_KEY = "HKCU:\Software\BitResearch\WSLSetup"

function Get-PhaseDone {
    param([Parameter(Mandatory)][string]$Phase)

    if (-not (Test-Path $STATE_KEY)) {
        return $false
    }

    try {
        $value = Get-ItemPropertyValue -Path $STATE_KEY -Name $Phase -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}


function Set-PhaseDone {
    param([Parameter(Mandatory)][string]$Phase)

    if (-not (Test-Path $STATE_KEY)) {
        New-Item -Path $STATE_KEY -Force | Out-Null
    }

    New-ItemProperty -Path $STATE_KEY `
        -Name $Phase `
        -PropertyType DWORD `
        -Value 1 `
        -Force | Out-Null
}

# ------------------------------
# Helpers
# ------------------------------
function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-DismFeatureState($FeatureName) {
    $stateLine = dism /online /get-featureinfo /featurename:$FeatureName |
                 Select-String "State :"
    return ($stateLine -split ':')[1].Trim()
}

function Test-WSLFeaturesEnabled {

    $wslState = Get-DismFeatureState "Microsoft-Windows-Subsystem-Linux"
    $vmState  = Get-DismFeatureState "VirtualMachinePlatform"

    $validStates = @("Enabled", "Enable Pending")

    return ($validStates -contains $wslState) -and
           ($validStates -contains $vmState)
}


function Enable-WSLFeatures {
    dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
    dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
}

function Register-PostBootTask {
    schtasks /create /tn $TASK_NAME /tr "powershell.exe -ExecutionPolicy Bypass -File `"$SCRIPT`"" /sc onlogon /ru "$env:USERNAME" /rl HIGHEST /f
}

function Remove-PostBootTask {
    schtasks /delete /tn $TASK_NAME /f 2>$null
}

function Register-WSLAutoStart {
    schtasks /create /tn "WSL-AutoStart" /tr "wsl -d Ubuntu -e true" /sc onlogon /ru "$env:USERNAME" /rl HIGHEST /f

}

function Phase1-Enable-WSLFeatures {
# =========================================================
# PHASE-1: SYSTEM FEATURE CHECK / ENABLE (ADMIN ONLY)
# =========================================================
    if (Test-IsAdmin -and -not (Test-WSLFeaturesEnabled)) {

        Write-Log "PHASE-1: WSL system features NOT enabled"

        # -----------------------------------------------------
        # This admin process is allowed to do ONLY:
        #   - Enable WSL features
        #   - Reboot
        # -----------------------------------------------------
        
        Register-PostBootTask
        # -----------------------------------------------------
        # ADMIN CONTEXT (HARD-LIMITED SECTION)
        # -----------------------------------------------------
        Write-Log "ADMIN: Enabling WSL system features"
        Enable-WSLFeatures

        Set-PhaseDone "Phase1"

        Write-Log "ADMIN: Rebooting system (required)"
        $choice = Read-Host "Reboot is required to continue setup. Reboot now? (Y/N)"
        if ($choice -match '^[Yy]$') {
            Write-Log "Rebooting system to continue setup..."
            Restart-Computer -Force
        } else {
            Write-Log "Reboot skipped. Please reboot manually to complete setup by rerun this script after restart, if script will not prompt automatically."
            Read-Host "Press ENTER to close this window"
            exit 1
        }

    }elseif (-not (Test-IsAdmin))
    {
        Write-Log "PHASE-1: Required admin privilege"
    }
    else
    {

        Write-Log "PHASE-1: WSL system features already enabled"
        Set-PhaseDone "Phase1"
    }

}


function Phase2-WSL-Setup {

    Write-Log "PHASE-2: Starting user WSL setup"

    $distros = wsl -l -q 2>$null
    if ($distros -notcontains $DISTRO) {
        Write-Log "PHASE-2: Installing WSL distro '$DISTRO' for user"
        wsl --install -d $DISTRO
    } else {
        Write-Log "PHASE-2: WSL distro '$DISTRO' already installed"
    }

    Write-Log "=== Phase 2: User Setup ==="

    $LINUX_USER = Read-Host "Enter Linux username"
    if ([string]::IsNullOrWhiteSpace($LINUX_USER)) {
        Write-Log "Linux username cannot be empty."
        Write-Log "Restart or rerun the same script to contiue"
        Read-Host "Press ENTER to close this window"
        exit 1
    }

$cmd = "useradd -m -s /bin/bash $LINUX_USER 2>/dev/null || true; " +
       "usermod -aG sudo $LINUX_USER; " +
       "passwd -d $LINUX_USER; " +
       "printf '[user]\ndefault=%s\n' '$LINUX_USER' > /etc/wsl.conf"

    wsl -d Ubuntu -u root -- bash -c "$cmd"

    Write-Log "Then user sets password on first login: by enter passwd in WSl"

}


function Phase3-Register-WSLAutoStart{
# =========================================================
# PHASE-3: SYSTEM FEATURE CHECK / ENABLE (ADMIN ONLY)
# =========================================================
    if (Test-IsAdmin) {    
        # Cleanup
        Remove-PostBootTask
        Write-Log "PHASE-2: Post-boot task removed"

        Register-WSLAutoStart
        Write-Log "PHASE-3: WSL auto-start task registered"
    }
    else
    {
        Write-Log "PHASE-3: Required admin privilege"
    }    
}

function Invoke-AsAdmin {
    param(
        [Parameter(Mandatory)]
        [string]$AdminAction
    )

    if (Test-IsAdmin) {
        Write-Log "Already admin, executing '$AdminAction'"
        & $AdminAction
        return
    }

    Write-Log "Requesting admin privileges for '$AdminAction'"

    Start-Process powershell `
        -Verb RunAs `
        -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`" -AdminAction $AdminAction"

    exit
}
 

Write-Log "SCRIPT STARTED"


# -------------------------------
# Phase 1 – Admin only
# -------------------------------
if (-not (Get-PhaseDone "Phase1")) {

    Invoke-AsAdmin Phase1-Enable-WSLFeatures

    # Relaunch ONLY if Phase1 completed (post-reboot)
    if (Get-PhaseDone "Phase1") {
        & powershell.exe -ExecutionPolicy Bypass -File "$PSCommandPath"
    }
    exit
}

# -------------------------------
# Phase 2 – Standard user
# -------------------------------
if ((Get-PhaseDone "Phase1") -and (-not (Get-PhaseDone "Phase2"))) {

    Phase2-WSL-Setup
    Set-PhaseDone "Phase2"
}

# -------------------------------
# Phase 3 – Admin only
# -------------------------------
if ((Get-PhaseDone "Phase2") -and (-not (Get-PhaseDone "Phase3"))) {

    Invoke-AsAdmin Phase3-Register-WSLAutoStart
    # Cleanup state after success
    Remove-Item -Recurse -Force $STATE_KEY
    Set-PhaseDone "Phase3"
    Read-Host "Press ENTER to close this window"
}



