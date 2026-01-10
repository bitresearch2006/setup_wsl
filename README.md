# Automated WSL Setup with Auto-Start

This repository provides PowerShell automation scripts to install, configure,
verify, and automatically start **WSL 2 (Ubuntu)** on Windows systems.

The setup follows a **two-phase installation model** with strict privilege
separation to ensure WSL is installed and owned by the intended Windows user.

---

## Features of this Setup

* Fully automated WSL 2 installation
* Two-phase setup with automatic resume after reboot
* System-wide WSL feature enablement (admin-only)
* User-owned Ubuntu installation (no admin ownership leakage)
* Linux user creation and default user configuration
* systemd support for background services
* Automatic WSL start at Windows login
* Clean uninstall and rollback support

---

## Prerequisites

* Windows 10 (2004+) or Windows 11
* PowerShell 5.1 or later
* Administrator privileges (for WSL feature enablement only)
* Virtualization enabled in BIOS
* Active internet connection

---

## Installation

### 1. Open PowerShell

Open **PowerShell as the user who should own WSL**.

> Do **not** permanently run PowerShell as Administrator.

---

### 2. Allow Script Execution (current session)

```powershell
Set-ExecutionPolicy RemoteSigned -Scope Process
```

---

### 3. Run the Installer

```powershell
.\install.ps1
```

---

## Installation Flow

### Phase 1 – System Preparation (Admin)

* Checks whether WSL Windows features are enabled
* If not enabled:

  * Requests administrator approval
  * Enables required Windows features
  * Registers a post-boot resume task
  * Forces a system reboot

No WSL distro is installed in this phase.

---

### Phase 2 – User WSL Setup (Standard User)

* Installs Ubuntu for the logged-in user
* Prompts for Linux username only (no password is requested)
* Creates the Linux user without a password
* Sets the created user as the default WSL user
* Removes post-boot resume task
* Registers WSL auto-start at Windows login
* Verifies installation

The Linux password must be set manually after login using passwd inside WSL.

This phase never runs in an admin-helper context.

---

## Verification

After installation completes, verify the setup using the following checks.

### Verify WSL Status

```powershell
wsl -l -v
```

## Confirm the task exists
schtasks /query /tn WSL-AutoStart /v /fo list

Verify Default User
wsl
whoami

* Ubuntu is listed
* Version is `2`

---

### Verify Default User

```powershell
wsl
whoami
```

Expected:

* Shell opens without errors
* `whoami` returns your Linux username (not root)

---

### Verify Auto-Start Task

```powershell
schtasks /query /tn WSL-AutoStart /v /fo list
```

Expected:

* Task exists
* Run As User is your Windows user

---

## Uninstall

### Run Uninstall Script

```powershell
.\uninstall.ps1
```

### What Uninstall Does

* Removes WSL auto-start task
* Removes post-boot resume task
* Unregisters Ubuntu (user-owned)
* Optionally disables WSL Windows features (admin approval required)
* Reboots only if features are disabled

---

## Possible Failures & Troubleshooting

1. **Virtualization not enabled**

   * Enable Intel VT-x / AMD-V in BIOS

2. **WSL feature enablement fails**

   * Ensure administrator credentials are correct

3. **Ubuntu install fails**

   * Check internet connectivity
   * Retry running `install.ps1`

4. **Auto-start not working**

   * Verify scheduled task exists
   * Ensure Windows user logs in normally

---

## Recommendations & Best Practices

* Use a dedicated Windows user if WSL is meant to run as a service
* Avoid running the installer permanently as Administrator
* Do not modify phase boundaries unless you understand the privilege model

---

## Windows Auto-Login (Optional)

This section describes how to configure automatic Windows login for a dedicated
service user so that WSL starts automatically after system boot.

### Option 1: Auto-Login Using netplwiz

**Prerequisite**

* Windows Hello enforcement must be disabled

**Steps**

1. Open **Settings**

2. Navigate to:

   Accounts → Sign-in options

3. Under **Additional settings**, turn OFF:

   > For improved security, only allow Windows Hello sign-in for Microsoft accounts on this device

4. Sign out or reboot

5. Press **Win + R**, run:

   ```
   netplwiz
   ```

6. Select the service user

7. Uncheck:

   > Users must enter a user name and password to use this computer

8. Click **Apply** and enter the password once
Click Apply

Enter the password once

9. Reboot

