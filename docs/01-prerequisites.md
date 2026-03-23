# Chapter 01 - Prerequisites

Before you begin setting up the distributed AI team, make sure you have everything listed below ready on all machines.

---

## 1.1 Hardware Requirements (Summary)

You need three Windows 11 machines connected on the same local network:

| Machine | GPU | VRAM | RAM | CPU Cores | IP Address |
|---------|-----|------|-----|-----------|------------|
| PC1 (Primary) | NVIDIA RTX 4090 | 24 GB | 64 GB | 32 | 192.168.1.106 |
| PC2 (Secondary) | NVIDIA RTX 2080 Ti | 11 GB | 64 GB | 24 | 192.168.1.112 |
| Laptop (Monitor) | NVIDIA Quadro T2000 | 4 GB | 64 GB | 12 | 192.168.1.113 |

> **Note**: The IP addresses above are examples from the reference architecture. Your actual IPs may differ. Use `ipconfig` in a terminal to find your machine's IP.

---

## 1.2 Software You Need to Install

Install the following on **every machine** before proceeding:

### 1.2.1 Windows 11 Updates

1. Open **Settings** > **Windows Update**
2. Click **Check for updates**
3. Install all available updates and restart if needed
4. Repeat until no more updates are available

> **Why?** Some GPU drivers and networking features require recent Windows updates.

### 1.2.2 NVIDIA GPU Drivers

1. Open a browser and go to: https://www.nvidia.com/drivers
2. Select your GPU model (e.g., RTX 4090, RTX 2080 Ti, or Quadro T2000)
3. Download and install the latest **Game Ready** or **Studio** driver
4. Restart your computer after installation

**Verify the driver is working:**

Open PowerShell (right-click Start button > "Terminal") and run:

```powershell
nvidia-smi
```

You should see output showing your GPU name, driver version, and CUDA version. Example:

```
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 560.xx       Driver Version: 560.xx       CUDA Version: 12.x    |
|-------------------------------+----------------------+----------------------+
| GPU  Name            | Bus-Id| Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf     | Mem-Usage      | GPU-Util  Compute M. |
|===============================+======================+======================|
|   0  NVIDIA GeForce RTX 4090 |   00000000:01:00.0  On |                  N/A |
| 30%   35C    P8     |  512MiB / 24564MiB |      0%      Default |
+-------------------------------+----------------------+----------------------+
```

> **If `nvidia-smi` is not found**: The NVIDIA driver didn't install correctly. Re-download and install it.

### 1.2.3 Git for Windows

1. Download Git from: https://git-scm.com/download/win
2. Run the installer
3. **Important settings during installation:**
   - Choose "Git from the command line and also from 3rd-party software"
   - Choose "Use bundled OpenSSH"
   - Choose "Checkout as-is, commit Unix-style line endings"
   - Keep all other defaults
4. Click **Install** and wait for completion

**Verify Git is installed:**

```powershell
git --version
```

Expected output: `git version 2.4x.x` (or newer)

### 1.2.4 Node.js (LTS Version)

Some OpenClaw components require Node.js.

1. Download Node.js LTS from: https://nodejs.org/
2. Run the installer with default settings
3. Restart your terminal after installation

**Verify Node.js is installed:**

```powershell
node --version
npm --version
```

### 1.2.5 Python 3.11+

1. Download Python from: https://www.python.org/downloads/
2. Run the installer
3. **IMPORTANT**: Check the box that says **"Add Python to PATH"** at the bottom of the first screen
4. Click **Install Now**

**Verify Python is installed:**

```powershell
python --version
pip --version
```

### 1.2.6 PowerShell 7+ (Optional but Recommended)

Windows 11 comes with PowerShell 5.1. The monitoring scripts in this guide work best with PowerShell 7+.

1. Open the existing PowerShell and run:

```powershell
winget install --id Microsoft.PowerShell --source winget
```

2. After installation, you can open PowerShell 7 by searching for "pwsh" in the Start menu.

**Verify:**

```powershell
pwsh --version
```

---

## 1.3 Accounts You Need

### 1.3.1 GitHub Account

You need a GitHub account for repository management.

1. Go to https://github.com and sign up (it's free)
2. You will generate SSH keys and Personal Access Tokens later in [Chapter 09](09-github-integration.md)

### 1.3.2 Telegram Account

You need a Telegram account to create the bot for human oversight.

1. Install Telegram on your phone or desktop: https://telegram.org
2. Create an account if you don't have one (requires a phone number)
3. You will create the bot itself in [Chapter 07](07-telegram-bot-setup.md)

### 1.3.3 Claude.ai Account (for External Consultant)

If you want to use Claude as an external consultant model:

1. Go to https://claude.ai and create an account
2. You will need an API key from https://console.anthropic.com
3. **Note**: The API has usage costs. Check pricing at https://www.anthropic.com/pricing

> **Important**: Do NOT purchase anything yet. This guide will tell you exactly when and what you need. The AI team itself is explicitly forbidden from making purchases.

---

## 1.4 Network Requirements

All three machines must be on the same local network with full TCP/IP connectivity.

### 1.4.1 Verify Network Connectivity

From each machine, ping the other two. Open PowerShell and run:

**From PC1 (192.168.1.106):**

```powershell
ping 192.168.1.112
ping 192.168.1.113
```

**From PC2 (192.168.1.112):**

```powershell
ping 192.168.1.106
ping 192.168.1.113
```

**From Laptop (192.168.1.113):**

```powershell
ping 192.168.1.106
ping 192.168.1.112
```

All pings should succeed with replies. If any fail, check:
- Are the machines on the same Wi-Fi/Ethernet network?
- Is Windows Firewall blocking ICMP? (See [Chapter 17 - Troubleshooting](17-troubleshooting.md))

### 1.4.2 Check Your IP Addresses

On each machine, run:

```powershell
ipconfig
```

Look for your **IPv4 Address** under your active network adapter (usually "Ethernet adapter" or "Wi-Fi adapter"). Write down the IP for each machine - you'll need them throughout this guide.

### 1.4.3 Firewall Configuration

The guide assumes no firewall restrictions between the three machines. If you have a corporate or third-party firewall:

- OpenClaw uses specific ports for inter-machine communication (configured in [Chapter 08](08-inter-machine-communication.md))
- Ollama defaults to port **11434**
- You may need to create inbound rules for these ports

---

## 1.5 Admin Privileges

You need **local administrator** access on all three machines. This is required for:

- Installing software (Ollama, OpenClaw, Git, etc.)
- Configuring network settings
- Running services
- Managing GPU resources

**Verify you have admin access:**

```powershell
net session 2>&1 | Out-Null; if ($LASTEXITCODE -eq 0) { "You have admin access" } else { "You do NOT have admin access" }
```

> **If you don't have admin access**: Contact your IT department or the machine owner. You cannot proceed without it.

---

## 1.6 Disk Space Requirements

Ensure each machine has enough free disk space:

| Machine | Minimum Free Space | Recommended | Why |
|---------|-------------------|-------------|-----|
| PC1 | 100 GB | 200 GB | Large models + repositories |
| PC2 | 60 GB | 100 GB | Medium models + repositories |
| Laptop | 30 GB | 50 GB | Small models + monitoring data |

**Check free disk space:**

```powershell
Get-PSDrive C | Select-Object @{N='Free(GB)';E={[math]::Round($_.Free/1GB,2)}}, @{N='Used(GB)';E={[math]::Round($_.Used/1GB,2)}}
```

---

## 1.7 Checklist Before Proceeding

Use this checklist to verify you're ready:

- [ ] All 3 machines are powered on and connected to the same network
- [ ] All machines can ping each other successfully
- [ ] Windows 11 is up to date on all machines
- [ ] NVIDIA drivers installed and `nvidia-smi` works on all machines
- [ ] Git installed on all machines
- [ ] Node.js installed on all machines
- [ ] Python 3.11+ installed on all machines
- [ ] You have admin access on all machines
- [ ] Sufficient disk space on all machines
- [ ] GitHub account created
- [ ] Telegram account created
- [ ] (Optional) Claude.ai / Anthropic account for external consultant

Once everything is checked off, proceed to [Chapter 02 - Hardware & Architecture](02-hardware-architecture.md).
