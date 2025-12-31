🔹 1. Title & Description (keep concise)
faasd README style
# faasd - Lightweight Serverless Setup (bitresearch2006 Edition)

This repository contains a custom installer and configuration for faasd...

WSL README should be
# Automated WSL Setup with Auto-Start

This repository provides PowerShell automation scripts to install, configure,
verify, and automatically start WSL 2 (Ubuntu) on Windows systems.


✔ Short
✔ Clear
✔ No instructions here

🔹 2. Features / What this Setup Provides
faasd style
## Features of this Setup
* Lightweight
* Multi-Arch
* Automated Networking

WSL README equivalent
## Features of this Setup

* Fully automated WSL 2 installation
* Two-phase setup with automatic resume after reboot
* Linux user creation and default user configuration
* systemd support for background services
* Automatic WSL start at Windows login
* Clean uninstall and rollback support


✔ Bullet list
✔ No commands
✔ No long explanations

🔹 3. Prerequisites (separate & explicit)
faasd style
## Prerequisites
* OS
* Permissions
* Ports

WSL README equivalent
## Prerequisites

* Windows 10 (2004+) or Windows 11
* Administrator privileges
* Virtualization enabled in BIOS
* Active internet connection
* PowerShell 5.1 or later


✔ Easy to scan
✔ No mixing with install steps

🔹 4. Installation section (this is critical)
faasd style

Numbered steps

Commands clearly isolated

Options clearly separated

WSL README should follow EXACTLY this
## Installation

### 1. Open PowerShell as Administrator

### 2. Allow Script Execution (current session)

```powershell
Set-ExecutionPolicy RemoteSigned -Scope Process

3. Run the Installer
.\install.ps1


✔ Each step has **one purpose**  
✔ Commands never mixed with explanation text  

---

## 🔹 5. Installation Flow (like “Post-Installation” in faasd)

### faasd style
```md
Post-Installation
Once the script finishes successfully...

WSL equivalent
## Installation Flow

### Phase 1 – WSL Installation
### Phase 2 – Linux User Setup


✔ Explains what happens
✔ No commands unless needed

🔹 6. Verification section (explicit)

faasd does this well with status checks.

WSL README equivalent:

## Verification

### Verify WSL Status

```powershell
wsl -l -v

Verify Default User
wsl
whoami


✔ Commands isolated  
✔ Expected behavior explained  

---

## 🔹 7. Uninstall section (mirrors Installation)

Your updated uninstall section already matches well, but aligned style:

```md
## Uninstall

### Run Uninstall Script

```powershell
.\uninstall.ps1

What Uninstall Does

Removes auto-start task

Shuts down WSL

Optionally unregisters Ubuntu


✔ Symmetry with install  
✔ No hidden behavior  

---

## 🔹 8. Troubleshooting / Possible Failures (separate)

faasd README avoids mixing failures into install steps — good practice.

Your WSL README should keep:

```md
## Possible Failures & Troubleshooting


With numbered scenarios, not paragraphs.


🔹 9. Recommendations / Best Practices (final section)

This aligns well with faasd “production mindset”.

---

Windows Auto-Login (Optional)

This section describes how to configure automatic Windows login for a dedicated service user so that WSL starts automatically after system boot.

This is intended only for background service usage.

When to Use Auto-Login

Use auto-login if:

WSL must run continuously

Linux services must start without manual login

You want to switch to another Windows user for daily work

Important Notes

Auto-login stores the user password on the system

Do not use a personal Windows account

Always use a dedicated service user

Recommended only for controlled environments

Option 1: Auto-Login Using netplwiz
Prerequisite

Windows Hello enforcement must be disabled.

Steps

Open Settings

Go to:

Accounts → Sign-in options


Under Additional settings, turn OFF:

For improved security, only allow Windows Hello sign-in for Microsoft accounts on this device


Sign out or reboot

Press Win + R

Run:

netplwiz


Select the service user

Uncheck:

Users must enter a user name and password to use this computer


Click Apply

Enter the password once

Reboot