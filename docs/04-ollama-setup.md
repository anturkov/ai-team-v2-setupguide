# Chapter 04 - Ollama Setup

This chapter covers installing Ollama on each machine and configuring it to serve AI models for the distributed team.

---

## 4.1 What is Ollama?

Ollama is a tool that runs large language models (LLMs) locally on your machine. It:

- Downloads and manages AI models
- Serves them via a local API (port 11434)
- Handles GPU/CPU allocation automatically
- Manages model loading and unloading based on available memory

OpenClaw communicates with Ollama on each machine to run AI inference.

---

## 4.2 Install Ollama on All Machines

### Step 1: Download Ollama

On **each machine**, open a browser and go to:

```
https://ollama.com/download/windows
```

Download the Windows installer.

### Step 2: Run the Installer

1. Double-click the downloaded `OllamaSetup.exe`
2. Follow the installer prompts (default settings are fine)
3. Ollama will install and start automatically

### Step 3: Verify Installation

Open PowerShell and run:

```powershell
ollama --version
```

Expected output: `ollama version 0.x.x` (or newer)

### Step 4: Verify Ollama is Running

```powershell
# Check if the Ollama service is running
ollama list
```

This should return an empty list (no models downloaded yet). If you get an error like "could not connect", Ollama's service isn't running:

```powershell
# Start Ollama manually if needed
ollama serve
```

> **Note**: Ollama runs as a background service on Windows. It starts automatically after installation and on boot.

---

## 4.3 Configure Ollama for Network Access

By default, Ollama only listens on `127.0.0.1` (localhost). OpenClaw on the same machine connects locally, so this is fine for basic operation. However, for direct cross-machine Ollama access (useful for debugging), you can configure it to listen on all interfaces.

### Step 1: Set Environment Variable

Open PowerShell **as Administrator**:

```powershell
# Allow Ollama to accept connections from any IP
[System.Environment]::SetEnvironmentVariable("OLLAMA_HOST", "0.0.0.0:11434", "Machine")
```

### Step 2: Set Concurrent Model Loading

By default, Ollama loads one model at a time. For the team to work efficiently:

```powershell
# Allow multiple models to be loaded simultaneously (up to available memory)
[System.Environment]::SetEnvironmentVariable("OLLAMA_MAX_LOADED_MODELS", "3", "Machine")

# Set how long idle models stay in memory (in minutes) - default is 5
[System.Environment]::SetEnvironmentVariable("OLLAMA_KEEP_ALIVE", "30m", "Machine")
```

**Recommended values per machine:**

| Machine | OLLAMA_MAX_LOADED_MODELS | OLLAMA_KEEP_ALIVE | Why |
|---------|-------------------------|-------------------|-----|
| PC1 | 2 | 30m | 24GB VRAM can hold coordinator + 1 other |
| PC2 | 2 | 15m | 11GB VRAM, swap models more frequently |
| Laptop | 1 | 10m | 4GB VRAM, keep memory free for monitoring |

### Step 3: Set GPU Layers

Control how many model layers run on GPU vs CPU:

```powershell
# PC1: Use all GPU layers (plenty of VRAM)
[System.Environment]::SetEnvironmentVariable("OLLAMA_NUM_GPU", "999", "Machine")

# PC2: Use all GPU layers
[System.Environment]::SetEnvironmentVariable("OLLAMA_NUM_GPU", "999", "Machine")

# Laptop: Limit GPU layers due to small VRAM
# Set this only on the laptop:
[System.Environment]::SetEnvironmentVariable("OLLAMA_NUM_GPU", "20", "Machine")
```

### Step 4: Restart Ollama

After setting environment variables, restart Ollama to apply them:

```powershell
# Stop Ollama
taskkill /f /im ollama.exe 2>$null
taskkill /f /im ollama_runners.exe 2>$null

# Wait a moment
Start-Sleep -Seconds 3

# Start Ollama again (it will pick up the new environment variables)
Start-Process "ollama" -ArgumentList "serve" -WindowStyle Hidden
```

### Step 5: Verify Network Access

From another machine, test if Ollama is accessible:

```powershell
# From PC2, test PC1's Ollama
Invoke-RestMethod -Uri "http://192.168.1.106:11434/api/tags" -Method GET
```

If you get a JSON response (even with an empty models list), it's working.

---

## 4.4 Download Models

Now download the AI models that each machine will run. This is the most time-consuming step — large models can take 20-60 minutes to download depending on your internet speed.

### 4.4.1 PC1 Models (192.168.1.106)

Open PowerShell on PC1:

```powershell
# Coordinator Model - This is the brain of the operation
# Qwen 2.5 Coder 32B - excellent at code and reasoning
ollama pull qwen2.5-coder:32b-instruct-q4_K_M

# Senior Engineer #1 - Architecture specialist
# DeepSeek Coder V2 - strong at code architecture
ollama pull deepseek-coder-v2:16b-lite-instruct-q4_K_M

# Senior Engineer #2 - Implementation specialist
# CodeLlama 13B - good at writing implementations
ollama pull codellama:13b-instruct-q4_K_M
```

> **Download times**: The 32B model is ~18 GB download. The others are ~8-9 GB each. Total for PC1: ~35 GB.

### 4.4.2 PC2 Models (192.168.1.112)

Open PowerShell on PC2:

```powershell
# Quality Agent - Code review and testing
# Qwen 2.5 Coder 7B - good balance of quality and speed
ollama pull qwen2.5-coder:7b-instruct-q4_K_M

# Security Agent - Security analysis
# Mistral 7B - strong general reasoning for security review
ollama pull mistral:7b-instruct-q4_K_M

# Backup/Overflow model - when Senior Engineers need PC2
ollama pull codellama:7b-instruct-q4_K_M
```

### 4.4.3 Laptop Models (192.168.1.113)

Open PowerShell on Laptop:

```powershell
# Monitoring Agent - lightweight resource tracker
# Phi-3 Mini - small but capable
ollama pull phi3:3.8b-mini-instruct-4k-q4_K_M

# DevOps Agent - deployment tasks
# Qwen 2.5 3B - small but effective for structured tasks
ollama pull qwen2.5:3b-instruct-q4_K_M
```

### 4.4.4 Verify All Models Downloaded

Run on each machine:

```powershell
ollama list
```

**PC1 should show:**
```
NAME                                          SIZE      MODIFIED
qwen2.5-coder:32b-instruct-q4_K_M           18 GB     just now
deepseek-coder-v2:16b-lite-instruct-q4_K_M  9.0 GB    just now
codellama:13b-instruct-q4_K_M               7.4 GB    just now
```

**PC2 should show:**
```
NAME                                          SIZE      MODIFIED
qwen2.5-coder:7b-instruct-q4_K_M            4.7 GB    just now
mistral:7b-instruct-q4_K_M                  4.1 GB    just now
codellama:7b-instruct-q4_K_M                3.8 GB    just now
```

**Laptop should show:**
```
NAME                                          SIZE      MODIFIED
phi3:3.8b-mini-instruct-4k-q4_K_M           2.2 GB    just now
qwen2.5:3b-instruct-q4_K_M                  1.9 GB    just now
```

---

## 4.5 Test Model Inference

Verify each model can run and produce output.

### Quick Test (on each machine):

```powershell
# Test the first model on each machine
ollama run qwen2.5-coder:32b-instruct-q4_K_M "What is 2+2? Answer in one word."
```

You should get a response like "Four" within a few seconds on PC1 (GPU), or up to 30 seconds on Laptop (partial CPU).

### API Test:

```powershell
# Test via API (this is how OpenClaw will communicate with Ollama)
$body = @{
    model = "qwen2.5-coder:32b-instruct-q4_K_M"
    prompt = "Say hello in one sentence."
    stream = $false
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/generate" -Method POST -Body $body -ContentType "application/json"
```

---

## 4.6 Create Custom Modelfiles (System Prompts)

Each agent needs a custom system prompt that defines its role. We create these using Ollama's Modelfile format.

> **All Modelfiles for every agent are in the [`models/`](../models/) directory at the root of this repository.** Detailed system prompts and parameters for each role are also documented inline in [Chapter 05 - Model Deployment](05-model-deployment.md). Here we show the mechanism.

### Example: Creating the Coordinator Model

Create a file at `C:\AI-Team\models\Modelfile-coordinator`:

```powershell
New-Item -ItemType File -Path "C:\AI-Team\models\Modelfile-coordinator" -Force
notepad C:\AI-Team\models\Modelfile-coordinator
```

Contents:

```dockerfile
FROM qwen2.5-coder:32b-instruct-q4_K_M

PARAMETER temperature 0.3
PARAMETER top_p 0.9
PARAMETER num_ctx 8192

SYSTEM """
You are the Coordinator of a distributed AI development team. Your responsibilities:
1. Receive tasks from the human operator via Telegram
2. Analyze and decompose tasks into sub-tasks
3. Assign sub-tasks to the appropriate team member
4. Track progress and resolve conflicts
5. Report results back to the human operator

You have final decision authority in disagreements between team members.
Always communicate clearly and provide status updates.
"""
```

Then create the custom model:

```powershell
ollama create coordinator -f C:\AI-Team\models\Modelfile-coordinator
```

Verify:

```powershell
ollama list
# Should now show "coordinator" in the list
```

> **Repeat this process for each agent** using the Modelfiles from the [`models/`](../models/) directory. All seven Modelfiles are provided:
>
> | Modelfile | Agent | Machine |
> |-----------|-------|---------|
> | `Modelfile-coordinator` | Coordinator / Dispatcher | PC1 |
> | `Modelfile-senior-eng-1` | Senior Engineer #1 (Architecture) | PC1 |
> | `Modelfile-senior-eng-2` | Senior Engineer #2 (Implementation) | PC1 |
> | `Modelfile-quality-agent` | Quality Agent | PC2 |
> | `Modelfile-security-agent` | Security Agent | PC2 |
> | `Modelfile-devops-agent` | DevOps Agent | Laptop |
> | `Modelfile-monitoring-agent` | Monitoring Agent | Laptop |
>
> Copy each Modelfile to `C:\AI-Team\models\` on the target machine and run `ollama create <name> -f <Modelfile>`. See [Chapter 05](05-model-deployment.md) for the full build commands.

---

## 4.7 Ollama Performance Tips

### 4.7.1 Check GPU Utilization

While a model is running, monitor GPU usage:

```powershell
# Run this in a separate terminal
nvidia-smi -l 2
```

This refreshes every 2 seconds. Watch for:
- **GPU-Util**: Should spike during inference (50-100%)
- **Memory-Usage**: Shows how much VRAM the model is using
- **Temperature**: Should stay below 85°C under load

### 4.7.2 Warm Up Models

Models are slow on first load. Pre-warm them after startup:

```powershell
# Warm up the coordinator model (PC1)
ollama run coordinator "Ready check. Respond with OK."
```

This loads the model into VRAM so the first real request is fast.

### 4.7.3 Monitor Model Loading

```powershell
# See which models are currently loaded in memory
ollama ps
```

Output shows model name, size, processor (GPU/CPU), and time until unload.

---

## 4.8 Checklist

- [ ] Ollama installed on PC1, PC2, and Laptop
- [ ] `ollama --version` works on all machines
- [ ] Environment variables set (OLLAMA_HOST, MAX_LOADED_MODELS, KEEP_ALIVE)
- [ ] Ollama restarted after setting environment variables
- [ ] All models downloaded on their respective machines
- [ ] Each model tested with a quick inference
- [ ] API inference works (`/api/generate` endpoint)
- [ ] GPU utilization confirmed during inference (`nvidia-smi`)

---

Next: [Chapter 05 - Model Deployment](05-model-deployment.md)
