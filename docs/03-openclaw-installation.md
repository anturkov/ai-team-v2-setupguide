# Chapter 03 - OpenClaw Installation (WSL2)

This chapter covers installing WSL2 on PC1 (ATU-RIG02) and setting up OpenClaw inside it. **Only PC1 needs OpenClaw** — PC2 (ATURIG01) and Laptop (LTATU01) just run Ollama on Windows native.

> **Why WSL2?** OpenClaw officially recommends WSL2 over native Windows: *"WSL2 is the more stable path and recommended for the full experience — the CLI, Gateway, and tooling run inside Linux with full compatibility."* Native Windows has known issues with SSH paths, exec approvals, and session tools.

---

## 3.1 What is OpenClaw?

OpenClaw is an open-source autonomous AI agent platform. It provides:

- **Gateway**: The process that manages all agents, channels (Telegram), and model routing
- **Multi-Agent**: Multiple agents on one Gateway, each with its own workspace, model, and personality
- **Agent-to-Agent Communication**: `sessions_send` and `sessions_spawn` tools for inter-agent task dispatch
- **Ollama Integration**: Connects to local and remote Ollama instances via HTTP API
- **Telegram Integration**: Native channel support for human interaction

### Our Architecture (Simplified)

```
PC1 / ATU-RIG02 (192.168.1.106)
┌─────────────────────────────────────────────────┐
│  WSL2 (Ubuntu 24.04)                             │
│  ┌─────────────────────────────────────────────┐ │
│  │  OpenClaw Gateway (:18789)                   │ │
│  │  - Coordinator agent                         │ │
│  │  - Senior Engineer #1 agent                  │ │
│  │  - Senior Engineer #2 agent                  │ │
│  │  - Quality Agent (→ PC2 Ollama)              │ │
│  │  - Security Agent (→ PC2 Ollama)             │ │
│  │  - DevOps Agent (→ Laptop Ollama)            │ │
│  │  - Monitoring Agent (→ Laptop Ollama)        │ │
│  │  - Telegram channel                          │ │
│  └─────────────┬───────────────────────────────┘ │
│                │ localhost:11434                   │
│  ┌─────────────▼───────────────────────────────┐ │
│  │  Ollama (Windows native)                     │ │
│  │  coordinator:latest, senior-eng-1, eng-2     │ │
│  └─────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘
         │                        │
         │ HTTP :11434            │ HTTP :11434
         ▼                        ▼
  PC2 / ATURIG01            Laptop / LTATU01
  Ollama: quality,          Ollama: devops,
  security agents           monitoring agents
```

---

## 3.2 Prerequisites (PC1 / ATU-RIG02 Only)

Before starting:
- Windows 11 version **22H2 or later** (required for WSL2 mirrored networking)
- Admin access on the machine
- Ollama already installed on Windows (see [Chapter 04](04-ollama-setup.md))

Check your Windows version:
```powershell
winver
```

---

## 3.3 Install WSL2 with Ubuntu

Run in **PowerShell as Administrator** on PC1 (ATU-RIG02):

```powershell
# Install WSL2 with Ubuntu 24.04
wsl --install -d Ubuntu-24.04
```

Reboot when prompted. After reboot, Ubuntu will open and ask you to create a Linux username and password.

### 3.3.1 Enable Systemd

Systemd is required for the OpenClaw Gateway daemon. Inside the Ubuntu terminal:

```bash
sudo tee /etc/wsl.conf << 'EOF'
[boot]
systemd=true

[network]
generateResolvConf=true
EOF
```

Then restart WSL from PowerShell:

```powershell
wsl --shutdown
```

Reopen Ubuntu and verify systemd is running:

```bash
systemctl --user status
```

### 3.3.2 Configure Mirrored Networking

Mirrored networking makes WSL2 share the same IP as the Windows host. This means the Gateway on port 18789 is directly accessible from the LAN without port forwarding.

Create the file `%UserProfile%\.wslconfig` on **Windows** (e.g., `C:\Users\atuadm\.wslconfig`):

```powershell
# Run in PowerShell on PC1 (ATU-RIG02)
@"
[wsl2]
networkingMode=mirrored
dnsTunneling=true
autoProxy=true
firewall=true
"@ | Out-File -FilePath "$env:USERPROFILE\.wslconfig" -Encoding UTF8
```

Restart WSL:

```powershell
wsl --shutdown
```

Reopen Ubuntu and verify the IP matches the Windows host:

```bash
# Should show 192.168.1.106 (same as Windows)
ip addr show eth0 | grep "inet "
```

### 3.3.3 Open Firewall for Gateway Port

The Hyper-V firewall needs a rule to allow LAN traffic to reach WSL2. Run in **PowerShell as Administrator**:

```powershell
# Allow OpenClaw Gateway port through Hyper-V firewall
New-NetFirewallHyperVRule -Name "OpenClawGateway" -DisplayName "OpenClaw Gateway (WSL2)" -Direction Inbound -VMCreatorId '{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}' -Protocol TCP -LocalPorts 18789

# Also add standard Windows Firewall rule
New-NetFirewallRule -DisplayName "OpenClaw Gateway LAN" -Direction Inbound -Protocol TCP -LocalPort 18789 -Action Allow
```

### 3.3.4 Verify WSL2 Can Reach Ollama on Windows

From inside Ubuntu:

```bash
# Should return Ollama version info
curl -s http://localhost:11434/api/version
```

With mirrored networking, `localhost` inside WSL2 reaches the Windows host. This is how OpenClaw will access the local Ollama.

---

## 3.4 Install OpenClaw in WSL2

Open the Ubuntu terminal on PC1 (ATU-RIG02):

```bash
# Install OpenClaw (this also installs Node.js 24 if needed)
curl -fsSL https://get.openclaw.ai | bash
```

After installation completes, run the onboarding wizard:

```bash
openclaw onboard
```

The wizard will ask:
1. **Mode**: Select `local` (we configure providers manually)
2. **Model provider**: Select `ollama` and point to `http://localhost:11434`
3. **Gateway**: Enable it, bind to LAN

> **If the wizard sets the wrong Ollama URL**, fix it afterward (see Section 3.6).

### 3.4.1 Install Gateway as Systemd Service

```bash
# Install as user-level systemd service
openclaw gateway install

# Verify it's running
openclaw gateway status
```

The Gateway should show as running on port 18789.

### 3.4.2 Auto-Start WSL2 on Boot (Optional)

By default, WSL2 shuts down when all terminals close. To keep it running:

**Inside Ubuntu:**
```bash
# Enable lingering so systemd services persist
sudo loginctl enable-linger "$(whoami)"
```

**In PowerShell as Administrator on Windows:**
```powershell
# Create scheduled task to start WSL at boot
schtasks /create /tn "WSL2 Auto-Start" /tr "wsl.exe -d Ubuntu-24.04 --exec /bin/true" /sc onstart /ru SYSTEM /f
```

---

## 3.5 Configure the Gateway

### 3.5.1 Set Elevated Mode (No Security Restrictions)

We want no approval prompts, no security limitations:

```bash
# Inside WSL2 on PC1 (ATU-RIG02)
openclaw config set tools.exec.security "full"
openclaw config set tools.exec.ask "off"
```

### 3.5.2 Verify Ollama Provider URL

The onboarding wizard may have set the wrong URL. Check:

```bash
openclaw config get models.providers.ollama.baseUrl
```

If it doesn't return `http://localhost:11434`, fix it:

```bash
openclaw config set models.providers.ollama.baseUrl "http://localhost:11434"
```

### 3.5.3 Bind Gateway to LAN

```bash
openclaw config set gateway.bind "lan"
```

This makes the Gateway accessible from other machines on the LAN (important for the Control UI).

### 3.5.4 Generate Gateway Token

```bash
openclaw doctor --generate-gateway-token
```

Note the token — you'll need it for the Control UI.

### 3.5.5 Restart and Verify

```bash
openclaw gateway restart
openclaw doctor --fix
```

---

## 3.6 Verify Installation

### Check Gateway is Running

```bash
openclaw gateway status
```

### Check Ollama Connectivity from WSL2

```bash
# Local Ollama on PC1 (ATU-RIG02)
curl -s http://localhost:11434/api/tags | head -20
```

### Check Gateway is Accessible from LAN

From **PC2 (ATURIG01)** or **Laptop (LTATU01)**, open a browser and navigate to:

```
http://192.168.1.106:18789
```

You should see the OpenClaw Control UI login page.

### Run Doctor

```bash
openclaw doctor --fix
```

Fix any issues it reports before proceeding.

---

## 3.7 Summary — What's Installed Where

| Machine | Component | How |
|---------|-----------|-----|
| PC1 (ATU-RIG02) | WSL2 Ubuntu 24.04 | `wsl --install -d Ubuntu-24.04` |
| PC1 (ATU-RIG02) | OpenClaw Gateway | Inside WSL2, systemd service |
| PC1 (ATU-RIG02) | Ollama | Windows native (see Chapter 04) |
| PC2 (ATURIG01) | Ollama only | Windows native (see Chapter 04) |
| Laptop (LTATU01) | Ollama only | Windows native (see Chapter 04) |

> **PC2 and Laptop do NOT need WSL2 or OpenClaw.** They are just Ollama HTTP servers that PC1's Gateway connects to for model inference.

---

## 3.8 Checklist

- [ ] WSL2 installed with Ubuntu 24.04 on PC1 (ATU-RIG02)
- [ ] Systemd enabled in `/etc/wsl.conf`
- [ ] Mirrored networking configured in `.wslconfig`
- [ ] Hyper-V firewall rule added for port 18789
- [ ] OpenClaw installed inside WSL2
- [ ] Gateway running as systemd service (`openclaw gateway status`)
- [ ] Ollama reachable from WSL2 (`curl http://localhost:11434/api/version`)
- [ ] Gateway accessible from LAN (browse to `http://192.168.1.106:18789`)
- [ ] `openclaw doctor --fix` reports no critical issues
- [ ] Elevated mode set (`tools.exec.security: "full"`, `tools.exec.ask: "off"`)

---

Next: [Chapter 04 - Ollama Setup](04-ollama-setup.md)
