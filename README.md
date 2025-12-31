
WSL Automated Setup with Auto-Start
1. Description

This project provides PowerShell automation scripts to install, configure, verify, and cleanly uninstall Windows Subsystem for Linux (WSL 2) with Ubuntu.

The setup is designed for scenarios where Linux services must be available automatically after Windows login, such as:

Background services

Tunnels (autossh)

Docker workloads

ROS / robotics

systemd-based daemons

Development and CI environments

The solution follows Microsoft-supported WSL behavior and avoids unsupported hacks.

2. How This Works (Concept Overview)

WSL itself does not start at Windows boot

WSL is started on user logon using a Windows Scheduled Task

When WSL starts:

systemd is initialized automatically

Enabled Linux services start without login or password

The installer runs in two phases:

Phase 1: Enable WSL + install Ubuntu (requires reboot)

Phase 2: Create Linux user, configure defaults, enable auto-start

After setup completes:

WSL starts automatically at every Windows login

No further user action is required

3. Prerequisites
Supported Systems

Windows 10 (Version 2004 / Build 19041 or later)

Windows 11

System Requirements

Administrator privileges

BIOS virtualization enabled (Intel VT-x / AMD-V)

Internet connectivity

PowerShell Requirements

Windows PowerShell 5.1 (default)

Scripts saved as UTF-8 with BOM (important)

4. Project Structure
File	Purpose
install.ps1	Install & configure WSL with auto-start
uninstall.ps1	Cleanly revert all changes
README.md	Documentation
5. Installation Instructions
5.1 Open PowerShell as Administrator

Right-click Start

Select Windows Terminal (Admin) or PowerShell (Admin)

5.2 Allow Script Execution (current session only)
Set-ExecutionPolicy RemoteSigned -Scope Process

5.3 Run Install Script
.\install.ps1

6. Installation Flow (What to Expect)
Phase 1 – WSL Installation

During the first run:

WSL features are enabled

Ubuntu (WSL 2) is installed

A reboot is required

You will be prompted:

WSL installation requires a reboot. Reboot now? (Y/N)


➡️ Reboot Windows
➡️ Log in again
➡️ The setup automatically resumes

Phase 2 – Linux User Setup

After reboot and login, the script resumes automatically and prompts:

Enter Linux username:
Enter Linux password:


The script then:

Creates the Linux user

Adds the user to sudo

Sets the user as default WSL user

Enables WSL auto-start at login

Performs verification

Cleans up temporary tasks

The script is idempotent and safe to re-run.

7. WSL Auto-Start Behavior
What “Auto-Start” Means

WSL does NOT start at Windows kernel boot

WSL starts automatically at every user login

This is the earliest supported and stable method

How It Is Implemented

A persistent scheduled task is created:

Property	Value
Task name	WSL-AutoStart
Trigger	User logon
Run as	Logged-in user
Privileges	Highest
Action	wsl -d Ubuntu -e true

This starts WSL silently in the background.

8. systemd Support (Recommended)

To enable Linux services at WSL startup:

sudo tee /etc/wsl.conf <<EOF
[boot]
systemd=true
EOF


Restart WSL:

wsl --shutdown


Result:

systemd starts automatically

Enabled services start without login

No password prompt required

9. Verification
Verify WSL is Running
wsl -l -v


Expected:

Ubuntu    Running    2

Verify Default User
wsl
whoami


Expected:

<your-username>

Verify systemd
ps -p 1 -o comm=


Expected:

systemd

10. Uninstall Instructions
10.1 What Uninstall Does

The uninstall script:

Disables WSL auto-start

Removes all scheduled tasks

Deletes setup state files

Shuts down WSL

Optionally unregisters Ubuntu

10.2 Run Uninstall

Open PowerShell as Administrator and run:

.\uninstall.ps1


You will be prompted:

Do you want to UNREGISTER the Ubuntu distro? (Y/N)

Choice	Result
Y	Completely removes Ubuntu (data deleted)
N	Keeps Ubuntu, removes automation
10.3 Verify Uninstall (Optional)
schtasks /query | findstr WSL


Expected:

(no output)

wsl -l -v


Ubuntu should be Stopped or unregistered.

11. Possible Failures & Troubleshooting
1️⃣ Script Parsing Errors

Ensure scripts are saved as UTF-8 with BOM

Avoid emojis or special Unicode characters

Avoid multiline PowerShell backticks

2️⃣ Bash $'\r' Errors

Do not use multiline bash -c commands

Ensure commands are single-line

3️⃣ WSL Not Auto-Starting

Verify scheduled task:

schtasks /query /tn WSL-AutoStart


Verify user logon occurred (not just boot)

4️⃣ Default User is root

Indicates Phase 2 did not complete

Re-run install.ps1

12. Recommendations & Best Practices

Use system-level systemd services, not user services

Add network dependencies for services:

After=network-online.target
Wants=network-online.target


Keep installer scripts ASCII-only

Avoid modifying scheduled tasks manually

13. Security Notes

Linux passwords are never stored

Passwords are cleared from memory after use

Scheduled tasks run with minimal scope

No interactive Linux login required for services

14. Common Use Cases

autossh tunnels

Docker / containers

ROS 2 nodes

Background Linux services

Always-on development environments

15. 🔐 Auto-Login Setup (Optional)

This section explains how to configure Windows automatic login for a dedicated service user so that WSL can start automatically after boot, even before switching to another user.

Purpose

Auto-login is useful when:

WSL must start automatically every day

Linux services must remain running in the background

You want to switch to another Windows user for daily work

Recommended pattern:

Windows boots

Service user logs in automatically

WSL auto-starts via scheduled task

You Switch User to your personal account

⚠️ Security Warning (Read First)

Auto-login stores the user password on the system

Anyone with physical access can access the auto-logged-in account

Do NOT use your personal Windows account

Use a dedicated service account only

Option A: Enable Auto-Login via netplwiz (Preferred)
Prerequisite

Windows Hello enforcement must be disabled.

Steps

Open Settings

Go to:

Accounts → Sign-in options


Under Additional settings, turn OFF:

“For improved security, only allow Windows Hello sign-in for Microsoft accounts on this device”


Reboot or sign out

Press Win + R

Type:

netplwiz


Select the service user

Uncheck:

Users must enter a user name and password to use this computer


Click Apply

Enter the user password once

Reboot

✅ Windows will now auto-login using this user.

Option B: Enable Auto-Login via Registry (Most Reliable)

Use this method if the checkbox does not appear or if Windows Hello must remain enabled.

Steps

Press Win + R

Type:

regedit


Navigate to:

HKEY_LOCAL_MACHINE
└─ SOFTWARE
   └─ Microsoft
      └─ Windows NT
         └─ CurrentVersion
            └─ Winlogon


Create or update the following values:

Name	Type	Value
AutoAdminLogon	REG_SZ	1
DefaultUserName	REG_SZ	<ServiceUser>
DefaultPassword	REG_SZ	<Password>
DefaultDomainName	REG_SZ	.

Close Registry Editor

Reboot

✅ Windows will auto-login as the service user.

Verify Auto-Login + WSL Startup

After reboot:

wsl -l -v


Expected output:

Ubuntu    Running    2

🛡️ Secure Hardening Checklist (Strongly Recommended)

When using auto-login, apply the following hardening measures.

Account Isolation

 Use a dedicated service user

 No browsing, email, or personal data

 No daily work under this account

Privilege Control

 Remove admin rights after setup (if not required)

 Keep admin access only if WSL services require it

 Do not use SYSTEM account for WSL

Physical & Local Security

 Enable BitLocker

 Configure automatic screen lock

 Require password on wake

 Disable guest accounts

Network & Access Control

 Disable RDP for the service user (if not needed)

 Restrict firewall access where possible

 Avoid exposing WSL services unnecessarily

WSL & Service Best Practices

 Use systemd services, not user services

 Add network dependency to services:

After=network-online.target
Wants=network-online.target


 Monitor long-running services

 Restart WSL periodically if uptime is critical

Recovery & Rollback

 Document auto-login changes

 Keep uninstall.ps1 accessible

 Know how to disable auto-login (registry or netplwiz)

Disable Auto-Login (Rollback)

To disable auto-login:

netplwiz

Re-enable:

Users must enter a user name and password to use this computer

Registry

Set:

AutoAdminLogon = 0


Reboot.

16. Summary

This project provides a robust, repeatable, and Microsoft-compliant way to:

Install WSL 2

Configure Linux users

Enable systemd

Start WSL automatically at login

Cleanly uninstall everything

It is suitable for production, research, and automation environments.