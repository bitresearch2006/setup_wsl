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

$TASK_NAME  = "WSL-PostBoot"
$SCRIPT     = $PSCommandPath
$STATE_KEY = "HKCU:\Software\BitResearch\WSLSetup"
$DISTRO	= "Select Distribution"

if (-not (Test-Path $STATE_KEY)) {
    New-Item -Path $STATE_KEY -Force | Out-Null
}

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

function Select-WSLDistro {

    $distros = wsl --list --online --quiet

    if (-not $distros) {
        Write-Error "No WSL distributions available."
        exit 1
    }

    Write-Log "`nAvailable WSL Distributions:`n"
    for ($i = 0; $i -lt $distros.Count; $i++) {
        Write-Log "[$($i+1)] $($distros[$i])"
    }

    do {
        $choice = Read-Host "`nSelect distro number"
    } while ($choice -notmatch '^\d+$' -or
             $choice -lt 1 -or
             $choice -gt $distros.Count)

    $rawChoice = $distros[$choice - 1]
    $distro    = $rawChoice.Trim().Split()[0]
    $distro = [System.Text.Encoding]::Unicode.GetString(
                [System.Text.Encoding]::Unicode.GetBytes($distro)
            )

    $distro = ($distro -replace '[^\x20-\x7E]', '').Trim()



    Write-Log "Selected raw   = $rawChoice"
    Write-Log "DISTRO length = $($distro.Length)"


    return $distro
}



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

function Clear-PhaseDone {
    param([Parameter(Mandatory)][string]$Phase)

    if (-not (Test-Path $STATE_KEY)) {
        return
    }

    if (Get-ItemProperty -Path $STATE_KEY -Name $Phase -ErrorAction SilentlyContinue) {
        Remove-ItemProperty -Path $STATE_KEY -Name $Phase -Force
    }
}


# ------------------------------
# Helpers
# ------------------------------
function Test-IsAdmin {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}


function Get-DismFeatureState {
    param([Parameter(Mandatory)][string]$FeatureName)

    $output = dism /online /get-featureinfo /featurename:$FeatureName 2>$null
    if (-not $output) {
        return $null
    }

    $stateLine = $output | Select-String '^\s*State\s*:'

    if (-not $stateLine) {
        return $null
    }

    return ($stateLine -split ':', 2)[1].Trim()
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

    $cmd = "/c start `"`" C:\Windows\System32\wsl.exe -d $DISTRO --exec sleep 28800"

    $action = New-ScheduledTaskAction `
        -Execute "cmd.exe" `
        -Argument $cmd

    $trigger = New-ScheduledTaskTrigger -AtLogOn # Changed from AtStartup to AtLogOn
    $trigger.Delay = "PT30S"

    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable

    Register-ScheduledTask `
        -TaskName "WSL-AutoStart" `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -User "$env:USERNAME" `
        -RunLevel Highest `
        -Force
}

function print-test-msg {
    $phase=(Get-PhaseDone "Phase1") 
    Write-Log "Phase1=$phase"
    $phase=(Get-PhaseDone "Phase2") 
    Write-Log "Phase2=$phase"
    $phase=(Get-PhaseDone "Phase3") 
    Write-Log "Phase3=$phase"
    Read-Host "Press ENTER to continue this window"
}

function Register-Task-Logon-Restart {
        Write-Log "ADMIN: Rebooting system (required)"
        $choice = Read-Host "Reboot is required to continue setup. Reboot now? (Y/N)"
        if ($choice -match '^[Yy]$') {
            # -----------------------------------------------------
            # This admin process is allowed to do ONLY:
            #   - Enable WSL features
            #   - Reboot
            # -----------------------------------------------------     
            Register-PostBootTask

            Write-Log "Rebooting system to continue setup..."
            Restart-Computer -Force
        } else {
            Write-Log "Reboot skipped. Please reboot manually to complete setup by rerun this script after restart, if script will not prompt automatically."
            Read-Host "Press ENTER to close this window"
            exit 1
        }

}

function Phase1-Enable-WSLFeatures {
# =========================================================
# PHASE-1: SYSTEM FEATURE CHECK / ENABLE (ADMIN ONLY)
# =========================================================

    if (-not (Test-IsAdmin)) {
        Write-Log "PHASE-1: Required admin privilege"
        return
    }


    $wsl_fea_status = Test-WSLFeaturesEnabled
    Write-Log "WSL-feature status = '$wsl_fea_status'"
    if (-not ($wsl_fea_status)) {

        Write-Log "PHASE-1: WSL system features NOT enabled"


        # -----------------------------------------------------
        # ADMIN CONTEXT (HARD-LIMITED SECTION)
        # -----------------------------------------------------
        Write-Log "ADMIN: Enabling WSL system features"
        Enable-WSLFeatures

        Set-PhaseDone "Phase1"

        Register-Task-Logon-Restart


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
        Write-Host "$DISTRO"
        Set-PhaseDone "Phase2"
        Write-Host ""
        Write-Log "Type 'exit' in Linux to gohead further steps"
        Write-Host ""
        # wsl --install $DISTRO
        Start-Process powershell -ArgumentList "-Command", "wsl --install $DISTRO"
        #Start-Process powershell -ArgumentList "-Command", "echo"
        print-test-msg
        Register-Task-Logon-Restart  
        exit

        Write-Log "Waiting for WSL distro to register..."
        while ($true) {
            $list = wsl -l -q 2>$null
            if ($list -contains $DISTRO) { break }
            Start-Sleep 2
        }

        Write-Log "Waiting for WSL first boot..."
        wsl -d $DISTRO -- echo "ready"
    } else {
        Write-Log "PHASE-2: WSL distro '$DISTRO' already installed"
    }

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

if (-not (Test-IsAdmin)) {
    Write-Log "[ERROR] This script must be run as Administrator."
    Write-Log "Please right-click PowerShell and choose 'Run as administrator'."
    exit 1
}
Write-Log "SCRIPT STARTED"
if ((Get-PhaseDone "Phase1") -and (Get-PhaseDone "Phase2") -and (Get-PhaseDone "Phase3"))
{
    Remove-Item -Recurse -Force $STATE_KEY
    if (-not (Test-Path $STATE_KEY)) {
       New-Item -Path $STATE_KEY -Force | Out-Null
    }
}
if (-not (Get-ItemProperty -Path $STATE_KEY -Name "DISTRO" -ErrorAction SilentlyContinue)) {
    $DISTRO = Select-WSLDistro
    Set-ItemProperty -Path $STATE_KEY -Name "DISTRO" -Value $DISTRO
}
else {
    $DISTRO = (Get-ItemProperty -Path $STATE_KEY).DISTRO
}


    Write-Log $DISTRO
    print-test-msg
# -------------------------------
# Phase 1 – Admin only
# -------------------------------
if (-not (Get-PhaseDone "Phase1")) {

    Phase1-Enable-WSLFeatures
}

# -------------------------------
# Phase 2 – Standard user also fine
# -------------------------------
if ((Get-PhaseDone "Phase1") -and (-not (Get-PhaseDone "Phase2"))) {

    Phase2-WSL-Setup
    if ((Get-PhaseDone "Phase1") -and (-not (Get-PhaseDone "Phase2"))) {
        Set-PhaseDone "Phase2"
        print-test-msg
    }

}

# -------------------------------
# Phase 3 – Admin only
# -------------------------------
if ((Get-PhaseDone "Phase2") -and (-not (Get-PhaseDone "Phase3"))) {

    Phase3-Register-WSLAutoStart
    # Cleanup state after success
    Remove-Item -Recurse -Force $STATE_KEY
    Set-PhaseDone "Phase3"
    Read-Host "Press ENTER to close this window"
}



