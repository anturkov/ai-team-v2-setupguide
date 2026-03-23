# Chapter 03 - OpenClaw Installation

This chapter walks you through installing and configuring OpenClaw on all three machines. OpenClaw is the backbone of your distributed AI team - it handles all communication, file management, and orchestration.

---

## 3.1 What is OpenClaw?

OpenClaw is a distributed AI orchestration platform that provides:

- **Model Discovery**: Automatically finds and registers AI models across your network
- **Message Routing**: Sends messages between models on different machines
- **File Management**: Synchronizes files and manages local storage
- **GitHub Integration**: Handles git operations (clone, push, pull, etc.)
- **Telegram Integration**: Connects your AI team to Telegram for human interaction
- **Health Monitoring**: Tracks model status and machine resources
- **Session Management**: Maintains conversation state and recovery

> **Architecture**: OpenClaw uses a **Gateway/Node** model. PC1 runs the Gateway (the central hub). PC2 and the Laptop run as Nodes that connect to it.

---

## 3.2 Installation on PC1 (Primary Gateway)

PC1 is your primary machine — it runs the OpenClaw Gateway that all other nodes connect to.

### Step 1: Install OpenClaw

Open PowerShell **as Administrator** (right-click > "Run as administrator"):

```powershell
powershell -c "irm https://openclaw.ai/install.ps1 | iex"
```

### Step 2: Verify Installation

Close and reopen PowerShell, then run:

```powershell
openclaw --version
```

You should see something like `OpenClaw 2026.x.x`. If you get "command not found", close and reopen PowerShell again — the installer updates your PATH.

### Step 3: Run Setup

Initialize the local config and agent workspace:

```powershell
openclaw setup
```

This creates the initial configuration files and workspace directories.

### Step 4: Configure PC1

Run the interactive configuration wizard:

```powershell
openclaw configure
```

This walks you through:
- Credentials and API keys
- Channel connections (Telegram, Discord, etc.)
- Gateway settings
- Agent defaults

For a fully guided first-time setup including workspace and skills:

```powershell
openclaw onboard
```

### Step 5: Validate Configuration

Check that everything is configured correctly:

```powershell
openclaw doctor
```

This runs health checks and suggests quick fixes if anything is misconfigured.

### Step 6: Start the Gateway on PC1

```powershell
# Start the Gateway (runs in the foreground for initial testing)
openclaw gateway run

# You should see output like:
# [INFO] OpenClaw Gateway 2026.x.x starting...
# [INFO] Listening on ws://0.0.0.0:18788
# [INFO] Waiting for nodes...
```

> **Tip**: Keep this terminal open for now. We'll set up the Gateway as a Windows service later so it starts automatically.

### Step 7: Open the Control Dashboard

```powershell
openclaw dashboard
```

This opens the Control UI in your browser where you can monitor all connected nodes.

---

## 3.3 Installation on PC2 (Secondary Node)

### Step 1: Install OpenClaw

Open PowerShell **as Administrator** on PC2:

```powershell
powershell -c "irm https://openclaw.ai/install.ps1 | iex"
```

### Step 2: Verify Installation

```powershell
openclaw --version
```

### Step 3: Run Setup

```powershell
openclaw setup
```

### Step 4: Configure PC2

```powershell
openclaw configure
```

When asked for the Gateway address, point it to PC1's IP:

```
Gateway host: 192.168.1.106
Gateway port: 18788
```

### Step 5: Validate

```powershell
openclaw doctor
```

### Step 6: Start the Node on PC2

```powershell
# Start PC2 as a node, connecting back to the PC1 gateway (foreground for initial testing)
openclaw node run

# You should see:
# [INFO] Node connecting to gateway at 192.168.1.106:18788...
# [INFO] Successfully paired with gateway
```

---

## 3.4 Installation on Laptop (Monitor Node)

### Step 1: Install OpenClaw

Open PowerShell **as Administrator** on the Laptop:

```powershell
powershell -c "irm https://openclaw.ai/install.ps1 | iex"
```

### Step 2: Verify Installation

```powershell
openclaw --version
```

### Step 3: Run Setup

```powershell
openclaw setup
```

### Step 4: Configure Laptop

```powershell
openclaw configure
```

Set the Gateway address to PC1:

```
Gateway host: 192.168.1.106
Gateway port: 18788
```

### Step 5: Validate

```powershell
openclaw doctor
```

### Step 6: Start the Node on Laptop

```powershell
openclaw node run
```

---

## 3.5 Verify Cluster Formation

Once all three machines are running, verify they can see each other.

### On PC1 (Gateway), run:

```powershell
# Check overall health
openclaw health

# Check channel and session status
openclaw status

# List connected nodes
openclaw nodes
```

### Run diagnostics on all machines:

```powershell
openclaw doctor
```

If any node is not connecting, check:
1. Is the Gateway running on PC1? (`openclaw health`)
2. Can you ping PC1 from the other machines?
3. Is the Gateway port open? (See [Chapter 17 - Troubleshooting](17-troubleshooting.md))

---

## 3.6 Install as a Windows Service

So OpenClaw starts automatically on boot and runs in the background.

### On PC1 — install the Gateway as a service:

```powershell
# Install the Gateway as a Windows scheduled task service
openclaw gateway install

# Start the service
openclaw gateway start

# Verify it's running
openclaw gateway status
```

**To manage the Gateway service later:**

```powershell
openclaw gateway stop
openclaw gateway restart
openclaw gateway uninstall
```

> **After this step**, you can close the terminal running the Gateway in the foreground. The service will keep it running in the background.

### On PC2 and Laptop — install the Node as a service:

```powershell
# Install the Node as a Windows scheduled task service
openclaw node install

# Start the service
openclaw node start    # Note: use 'restart' if already running

# Verify it's running
openclaw node status
```

**To manage the Node service later:**

```powershell
openclaw node stop
openclaw node restart
openclaw node uninstall
```

> **After this step**, you can close the terminal running the Node in the foreground. The service will keep it running in the background.

---

## 3.7 Updating OpenClaw

When a new version is released, run on each machine:

```powershell
openclaw update
```

To check available update channels:

```powershell
openclaw update --help
```

---

## 3.8 Useful Commands Reference

| Command | Description |
|---|---|
| `openclaw setup` | Initialize config and workspace |
| `openclaw configure` | Interactive credentials and channel setup |
| `openclaw onboard` | Full guided first-time setup |
| `openclaw gateway run` | Start the Gateway in foreground (PC1) |
| `openclaw gateway install` | Install Gateway as Windows service |
| `openclaw gateway start/stop/restart` | Manage the Gateway service |
| `openclaw gateway status` | Show Gateway service status |
| `openclaw node run` | Start the Node in foreground (PC2, Laptop) |
| `openclaw node install` | Install Node as Windows service |
| `openclaw node stop/restart` | Manage the Node service |
| `openclaw node status` | Show Node service status |
| `openclaw health` | Fetch health from the running gateway |
| `openclaw status` | Show channel health and recent sessions |
| `openclaw doctor` | Health checks + quick fixes |
| `openclaw nodes` | Manage gateway-owned node pairing |
| `openclaw dashboard` | Open Control UI in browser |
| `openclaw logs` | Tail gateway logs |
| `openclaw reset` | Reset local config/state (keeps CLI) |

---

## 3.9 Checklist

- [ ] OpenClaw installed on PC1, PC2, and Laptop
- [ ] `openclaw --version` works on all machines
- [ ] `openclaw setup` completed on all machines
- [ ] `openclaw configure` completed on all machines (Gateway address set on PC2 and Laptop)
- [ ] `openclaw doctor` passes on all machines
- [ ] Gateway running on PC1 (`openclaw gateway run`)
- [ ] Nodes connected on PC2 and Laptop (`openclaw node run`)
- [ ] All nodes visible via `openclaw nodes` on PC1
- [ ] Gateway installed as a Windows service on PC1
- [ ] Node service installed on PC2 and Laptop

---

Next: [Chapter 04 - Ollama Setup](04-ollama-setup.md)
