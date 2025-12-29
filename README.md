WSL Automated Setup with Auto-Start

This project provides PowerShell automation scripts to install, configure, and cleanly uninstall Windows Subsystem for Linux (WSL 2) with Ubuntu, including automatic startup at Windows boot.

The setup is designed for background services, tunnels, Docker, ROS, and systemd-based workloads.

📌 Features

Enable WSL and Virtual Machine Platform

Install Ubuntu (WSL 2)

Prompt for Linux username & password

Create Linux user automatically

Set default WSL user

Auto-start WSL at Windows boot

Support systemd services without interactive login

Clean uninstall & rollback support

🖥️ Supported Systems

Windows 10 (2004 / Build 19041+)

Windows 11

Administrator privileges required

BIOS virtualization enabled (Intel VT-x / AMD-V)

📂 Files
File	Purpose
install.ps1	Install & configure WSL
uninstall_wsl_setup.ps1	Revert all changes
README.md	Documentation
🚀 Installation & Setup
1️⃣ Open PowerShell as Administrator

Right-click Start

Select Windows Terminal (Admin) or PowerShell (Admin)

2️⃣ Allow script execution (session only)
Set-ExecutionPolicy RemoteSigned -Scope Process

3️⃣ Run the install script
.\install.ps1

🔁 First-Run Requirement (Important)

On the first execution:

Windows features are enabled

Ubuntu is installed

Windows reboot is required

You will see:

Ubuntu installed. Please RESTART Windows and re-run this script.


👉 Restart Windows
👉 Run the same script again as Administrator

👤 Linux User Creation

On the second run, the script will prompt:

Enter Linux username:
Enter Linux password:


Actions performed:

Linux user is created

User is added to sudo

User is set as default WSL user

Auto-start task is registered

The script is idempotent and safe to re-run.

🔄 Automatic WSL Startup

A Windows Task Scheduler entry is created:

Task name: AutoStartWSL

Trigger: Windows boot

Run as: SYSTEM

Starts WSL silently in background

Verify
schtasks /query /tn AutoStartWSL

Test without reboot
schtasks /run /tn AutoStartWSL

⚙️ systemd Support (Recommended)

To run Linux services automatically:

sudo tee /etc/wsl.conf <<EOF
[boot]
systemd=true
EOF


Restart WSL:

wsl --shutdown


✔ systemd starts automatically
✔ No login or password required
✔ Enabled services start at boot

🧪 Verification
wsl

whoami
ps -p 1 -o comm=


Expected:

systemd

🧹 Uninstall & Rollback

Use this when you want to completely revert everything done by the install script.

⚠️ Warning

Uninstalling will:

Permanently delete the Ubuntu WSL filesystem

Remove Linux users and configuration

Remove auto-start behavior

▶️ Uninstall Steps
1️⃣ Open PowerShell as Administrator
2️⃣ Run uninstall script
.\uninstall_wsl_setup.ps1

3️⃣ Optional prompt

The script will ask:

Disable WSL Windows features as well? (y/N)

Choice	Result
y	Fully removes WSL from Windows (reboot required)
N	Keeps WSL enabled but removes Ubuntu
🧪 Verify Uninstall
Check distros
wsl -l


Expected:

No installed distributions.

Check startup task
schtasks /query /tn AutoStartWSL


Expected:

ERROR: The system cannot find the file specified.

Check WSL status (if disabled)
wsl --status


Expected:

WSL is not installed.

🔐 Security Notes

Linux passwords are never stored

Scripts must be run as Administrator

Startup task runs as SYSTEM for reliability

No interactive Linux login required for services

🧩 Common Use Cases

autossh / tunnel services

Docker / container workloads

ROS 2 nodes

Always-on Linux daemons

CI / development environments

📝 Notes

User-level systemd services (systemctl --user) do not auto-start

Use system-level services for boot tasks

Network-dependent services should include:

After=network-online.target
Wants=network-online.target
