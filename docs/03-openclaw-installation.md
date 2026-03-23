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

> **Key Point**: OpenClaw replaces the need for custom Python routing scripts. Everything goes through OpenClaw's native capabilities.

---

## 3.2 Installation on PC1 (Primary Coordinator)

PC1 is your primary machine, so we install and configure it first.

### Step 1: Download OpenClaw

Open PowerShell **as Administrator** (right-click > "Run as administrator"):

```powershell
# Navigate to the AI-Team directory
cd C:\AI-Team

# Download the latest OpenClaw release
# Replace the URL below with the actual OpenClaw download URL from their official site
Invoke-WebRequest -Uri "https://github.com/openclaw/openclaw/releases/latest/download/openclaw-windows-x64.zip" -OutFile "openclaw.zip"
```

> **Note**: If the above URL doesn't work, visit the official OpenClaw GitHub repository or website to find the latest Windows release download link.

### Step 2: Extract the Archive

```powershell
# Extract to the openclaw directory
Expand-Archive -Path "openclaw.zip" -DestinationPath "C:\AI-Team\openclaw" -Force

# Verify extraction
Get-ChildItem C:\AI-Team\openclaw
```

You should see the OpenClaw binary and supporting files.

### Step 3: Add OpenClaw to System PATH

This lets you run `openclaw` from any terminal:

```powershell
# Add to system PATH (requires admin)
$currentPath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
$newPath = "$currentPath;C:\AI-Team\openclaw"
[System.Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")

# Refresh the current session
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
```

### Step 4: Verify Installation

Close and reopen PowerShell, then run:

```powershell
openclaw --version
```

You should see the version number. If you get "command not found", the PATH wasn't set correctly — try reopening PowerShell as Administrator.

### Step 5: Initialize OpenClaw for PC1

```powershell
# Initialize OpenClaw with coordinator role
openclaw init --role coordinator --name "pc1-coordinator" --data-dir "C:\AI-Team\openclaw\data"
```

This creates the initial configuration files in `C:\AI-Team\openclaw\config\`.

### Step 6: Configure PC1 as Coordinator

Edit the configuration file that was generated:

```powershell
notepad C:\AI-Team\openclaw\config\openclaw.yaml
```

Set the following values (a complete config file is provided in [configs/openclaw-pc1.yaml](configs/openclaw-pc1.yaml)):

```yaml
# OpenClaw Configuration - PC1 (Coordinator)
node:
  name: "pc1-coordinator"
  role: "coordinator"          # This machine is the central coordinator
  host: "192.168.1.106"
  port: 8080

# Cluster configuration - all machines in the team
cluster:
  discovery:
    mode: "static"             # Use static IPs (simpler for small clusters)
    nodes:
      - name: "pc1-coordinator"
        host: "192.168.1.106"
        port: 8080
        role: "coordinator"
      - name: "pc2-worker"
        host: "192.168.1.112"
        port: 8080
        role: "worker"
      - name: "laptop-monitor"
        host: "192.168.1.113"
        port: 8080
        role: "worker"

# Ollama integration
ollama:
  host: "127.0.0.1"           # Ollama runs locally on each machine
  port: 11434

# Logging
logging:
  level: "info"                # Options: debug, info, warn, error
  file: "C:\\AI-Team\\openclaw\\logs\\openclaw.log"
  max_size_mb: 100
  max_files: 5
```

### Step 7: Start OpenClaw on PC1

```powershell
# Start OpenClaw in the foreground (for initial testing)
openclaw start

# You should see output like:
# [INFO] OpenClaw v1.x.x starting...
# [INFO] Node: pc1-coordinator (coordinator)
# [INFO] Listening on 192.168.1.106:8080
# [INFO] Waiting for cluster nodes...
```

> **Tip**: Keep this terminal open for now. We'll set up OpenClaw as a Windows service later so it starts automatically.

---

## 3.3 Installation on PC2 (Secondary Worker)

Repeat the same download and extraction steps on PC2.

### Step 1-4: Download, Extract, PATH, Verify

Follow the exact same Steps 1-4 from Section 3.2 above on PC2.

### Step 5: Initialize OpenClaw for PC2

```powershell
openclaw init --role worker --name "pc2-worker" --data-dir "C:\AI-Team\openclaw\data"
```

### Step 6: Configure PC2

Edit the configuration (or copy from [configs/openclaw-pc2.yaml](configs/openclaw-pc2.yaml)):

```powershell
notepad C:\AI-Team\openclaw\config\openclaw.yaml
```

```yaml
# OpenClaw Configuration - PC2 (Worker)
node:
  name: "pc2-worker"
  role: "worker"               # This machine is a worker node
  host: "192.168.1.112"
  port: 8080

# Must match the coordinator's cluster config
cluster:
  discovery:
    mode: "static"
    coordinator:
      host: "192.168.1.106"    # Points to PC1
      port: 8080

# Ollama integration
ollama:
  host: "127.0.0.1"
  port: 11434

# Logging
logging:
  level: "info"
  file: "C:\\AI-Team\\openclaw\\logs\\openclaw.log"
  max_size_mb: 100
  max_files: 5
```

### Step 7: Start OpenClaw on PC2

```powershell
openclaw start
```

You should see it connect to the coordinator on PC1:

```
[INFO] OpenClaw v1.x.x starting...
[INFO] Node: pc2-worker (worker)
[INFO] Connecting to coordinator at 192.168.1.106:8080...
[INFO] Successfully joined cluster
```

---

## 3.4 Installation on Laptop (Monitor)

### Step 1-4: Download, Extract, PATH, Verify

Same as before — follow Steps 1-4 from Section 3.2.

### Step 5: Initialize OpenClaw for Laptop

```powershell
openclaw init --role worker --name "laptop-monitor" --data-dir "C:\AI-Team\openclaw\data"
```

### Step 6: Configure Laptop

Edit the configuration (or copy from [configs/openclaw-laptop.yaml](configs/openclaw-laptop.yaml)):

```yaml
# OpenClaw Configuration - Laptop (Monitor)
node:
  name: "laptop-monitor"
  role: "worker"
  host: "192.168.1.113"
  port: 8080

cluster:
  discovery:
    mode: "static"
    coordinator:
      host: "192.168.1.106"
      port: 8080

ollama:
  host: "127.0.0.1"
  port: 11434

logging:
  level: "info"
  file: "C:\\AI-Team\\openclaw\\logs\\openclaw.log"
  max_size_mb: 100
  max_files: 5
```

### Step 7: Start OpenClaw on Laptop

```powershell
openclaw start
```

---

## 3.5 Verify Cluster Formation

Once all three machines have OpenClaw running, verify they can see each other.

### On PC1 (Coordinator), run:

```powershell
openclaw cluster status
```

Expected output:

```
Cluster Status: HEALTHY
═══════════════════════════════════════════════════════════
Node                Role          Status    Last Seen
───────────────────────────────────────────────────────────
pc1-coordinator     coordinator   ONLINE    just now
pc2-worker          worker        ONLINE    2s ago
laptop-monitor      worker        ONLINE    1s ago
═══════════════════════════════════════════════════════════
Total nodes: 3/3 online
```

If any node shows as OFFLINE, check:
1. Is OpenClaw running on that machine?
2. Can you ping that machine from PC1?
3. Is port 8080 open? (See [Chapter 17 - Troubleshooting](17-troubleshooting.md))

---

## 3.6 Install OpenClaw as a Windows Service

So OpenClaw starts automatically on boot and runs in the background:

**Run on each machine:**

```powershell
# Register OpenClaw as a Windows service (requires admin PowerShell)
openclaw service install

# Start the service
openclaw service start

# Verify the service is running
openclaw service status
```

**To manage the service later:**

```powershell
# Stop the service
openclaw service stop

# Restart the service
openclaw service restart

# Remove the service (if needed)
openclaw service uninstall
```

> **After this step**, you can close the terminal windows that were running OpenClaw in the foreground. The service will keep it running in the background.

---

## 3.7 Updating OpenClaw

When a new version is released:

```powershell
# Stop the service first
openclaw service stop

# Download the new version
cd C:\AI-Team
Invoke-WebRequest -Uri "https://github.com/openclaw/openclaw/releases/latest/download/openclaw-windows-x64.zip" -OutFile "openclaw-update.zip"

# Back up the current version
Copy-Item -Path "C:\AI-Team\openclaw" -Destination "C:\AI-Team\openclaw-backup" -Recurse

# Extract the update (config files are preserved)
Expand-Archive -Path "openclaw-update.zip" -DestinationPath "C:\AI-Team\openclaw" -Force

# Restart the service
openclaw service start

# Verify
openclaw --version
openclaw cluster status
```

---

## 3.8 Checklist

- [ ] OpenClaw installed on PC1, PC2, and Laptop
- [ ] OpenClaw added to PATH on all machines
- [ ] `openclaw --version` works on all machines
- [ ] Configuration files customized for each machine's role and IP
- [ ] All three nodes appear as ONLINE in `openclaw cluster status`
- [ ] OpenClaw installed as a Windows service on all machines
- [ ] Service starts automatically after reboot (test by restarting one machine)

---

Next: [Chapter 04 - Ollama Setup](04-ollama-setup.md)
