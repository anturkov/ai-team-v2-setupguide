# Chapter 02 - Hardware & Architecture

This chapter provides a detailed breakdown of the hardware, network topology, and how each machine fits into the distributed AI team.

---

## 2.1 Machine Specifications

### 2.1.1 PC1 - Primary Coordinator (192.168.1.106)

| Component | Specification | Role in System |
|-----------|--------------|----------------|
| GPU | NVIDIA RTX 4090 | Runs the largest models (Coordinator, Senior Engineers) |
| VRAM | 24 GB | Can load 1 large model (70B Q4) or 2-3 medium models |
| RAM | 64 GB | Overflow for models that exceed VRAM, plus OS and services |
| CPU | 32 cores | Handles concurrent inference and OpenClaw orchestration |
| Role | **Primary Coordinator** | Central hub for task distribution and Telegram bot |

**What runs on PC1:**
- Coordinator/Dispatcher model (always loaded)
- Senior Engineer #1 (Architecture) - primary location
- Senior Engineer #2 (Implementation) - primary location
- OpenClaw node (coordinator mode)
- Telegram bot service

### 2.1.2 PC2 - Secondary Worker (192.168.1.112)

| Component | Specification | Role in System |
|-----------|--------------|----------------|
| GPU | NVIDIA RTX 2080 Ti | Runs medium-sized specialized models |
| VRAM | 11 GB | Can load 1-2 medium models (7B-13B range) |
| RAM | 64 GB | Supports CPU-offloaded layers for larger models |
| CPU | 24 cores | Good for parallel inference tasks |
| Role | **Secondary Worker** | Specialized agents (Quality, Security, overflow) |

**What runs on PC2:**
- Quality Agent (Code review, testing)
- Security Agent (Security analysis)
- Senior Engineer overflow (when PC1 is busy)
- OpenClaw node (worker mode)

### 2.1.3 Laptop - Monitor & Light Duties (192.168.1.113)

| Component | Specification | Role in System |
|-----------|--------------|----------------|
| GPU | NVIDIA Quadro T2000 | Runs small, efficient models only |
| VRAM | 4 GB | Limited to small models (3B-7B Q4) |
| RAM | 64 GB | Can run larger models in CPU mode if needed |
| CPU | 12 cores | Adequate for monitoring and light inference |
| Role | **Monitor & Light Duties** | System monitoring, DevOps tasks |

**What runs on Laptop:**
- Monitoring Agent (resource tracking)
- DevOps Agent (deployment tasks)
- OpenClaw node (worker mode)
- Monitoring dashboard

---

## 2.2 Network Architecture

```
                    Local Network: 192.168.1.0/24
                    ================================

    ┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
    │  PC1             │     │  PC2             │     │  Laptop          │
    │  192.168.1.106   │     │  192.168.1.112   │     │  192.168.1.113   │
    │                  │     │                  │     │                  │
    │  OpenClaw:8080   │◄───►│  OpenClaw:8080   │◄───►│  OpenClaw:8080   │
    │  Ollama:11434    │     │  Ollama:11434    │     │  Ollama:11434    │
    │  Telegram Bot    │     │                  │     │  Dashboard:3000  │
    └──────────────────┘     └──────────────────┘     └──────────────────┘
           │                                                   │
           │  Telegram Bot API                                 │
           ▼                                                   ▼
    ┌──────────────┐                                  ┌──────────────────┐
    │  Telegram    │                                  │  GitHub.com      │
    │  Cloud API   │                                  │  (Repositories)  │
    └──────────────┘                                  └──────────────────┘
```

### 2.2.1 Ports Used

| Port | Service | Used On | Description |
|------|---------|---------|-------------|
| 8080 | OpenClaw API | All machines | Inter-model communication and orchestration |
| 11434 | Ollama API | All machines | Model inference (loading, running, managing models) |
| 3000 | Monitoring Dashboard | Laptop | Web-based monitoring UI |
| 443 | HTTPS (outbound) | PC1 | Telegram Bot API, GitHub API, Claude API |

> **Note**: Port numbers can be customized during setup. The ones above are defaults used throughout this guide.

### 2.2.2 Communication Flow

1. **Human → System**: You send a message to the Telegram bot
2. **Telegram → PC1**: The bot service on PC1 receives your message
3. **PC1 Coordinator**: The coordinator model analyzes the task
4. **Coordinator → Team**: OpenClaw routes sub-tasks to the appropriate models on any machine
5. **Team → Coordinator**: Results flow back through OpenClaw
6. **Coordinator → Human**: The coordinator sends the response via Telegram

All inter-model communication uses OpenClaw's native messaging. There are no custom scripts routing messages.

---

## 2.3 VRAM Budget Planning

VRAM is your most constrained resource. Here's how to plan model allocation:

### 2.3.1 Understanding VRAM Usage

| Model Size | Quantization | Approximate VRAM | Example Models |
|------------|-------------|-------------------|----------------|
| 3B | Q4_K_M | ~2.5 GB | Phi-3 Mini, Llama 3.2 3B |
| 7B | Q4_K_M | ~4.5 GB | Mistral 7B, Llama 3.1 8B, Qwen 2.5 7B |
| 13B | Q4_K_M | ~8 GB | Llama 2 13B, Qwen 2.5 14B |
| 34B | Q4_K_M | ~20 GB | CodeLlama 34B, Qwen 2.5 32B |
| 70B | Q4_K_M | ~40 GB | Llama 3.1 70B (needs CPU offload) |

> **Q4_K_M** is a quantization level that balances quality and VRAM usage. Lower quantization (Q2, Q3) uses less VRAM but reduces quality. Higher quantization (Q5, Q6, Q8) uses more VRAM but gives better results.

### 2.3.2 VRAM Allocation Plan

**PC1 - 24 GB VRAM:**

| Model | Est. VRAM | Priority | Notes |
|-------|-----------|----------|-------|
| Coordinator (Qwen 2.5 32B Q4) | ~20 GB | Always loaded | Primary model, always in memory |
| Senior Eng #1 (loaded on demand) | ~4-8 GB | On demand | Loaded when needed, coordinator unloaded partially |
| Senior Eng #2 (loaded on demand) | ~4-8 GB | On demand | Alternates with Senior Eng #1 |

> **Important**: PC1 cannot run all models simultaneously. Ollama manages loading/unloading automatically. The coordinator stays resident; other models swap in and out.

**PC2 - 11 GB VRAM:**

| Model | Est. VRAM | Priority | Notes |
|-------|-----------|----------|-------|
| Quality Agent (7B Q4) | ~4.5 GB | High | Frequently used for reviews |
| Security Agent (7B Q4) | ~4.5 GB | Medium | Loaded for security analysis |
| Reserve | ~2 GB | - | Buffer for OS and CUDA overhead |

**Laptop - 4 GB VRAM:**

| Model | Est. VRAM | Priority | Notes |
|-------|-----------|----------|-------|
| Monitoring Agent (3B Q4) | ~2.5 GB | Always loaded | Lightweight, always running |
| DevOps Agent (3B Q4) | ~2.5 GB | On demand | Swaps with Monitoring when needed |

### 2.3.3 CPU Offloading Strategy

When a model doesn't fit entirely in VRAM, Ollama can offload some layers to system RAM (CPU mode). This is slower but allows running larger models:

- **PC1**: Can run a 70B Q4 model with ~20 GB in VRAM and ~20 GB offloaded to RAM
- **PC2**: Can run a 13B Q4 model with ~8 GB in VRAM and remainder in RAM
- **Laptop**: Can run a 7B Q4 model entirely in RAM (CPU-only) as a fallback

> **Performance Impact**: CPU-offloaded layers are 5-10x slower than GPU layers. Use this only when the larger model quality justifies the speed trade-off.

---

## 2.4 Redundancy and Failover

### 2.4.1 What Happens When a Machine Goes Down?

| Scenario | Impact | Automatic Recovery |
|----------|--------|-------------------|
| PC1 goes down | Coordinator lost, Telegram bot offline | PC2 can run backup coordinator (see [Chapter 14](14-error-handling-recovery.md)) |
| PC2 goes down | Quality/Security agents offline | Tasks queue until PC2 returns or coordinator reassigns to PC1 |
| Laptop goes down | Monitoring/DevOps offline | System continues without monitoring; alerts stop |
| Network partition | Machines can't communicate | Each machine continues local work; syncs when reconnected |

### 2.4.2 Minimum Viable System

The system can operate with just PC1 alone (degraded mode):
- Coordinator handles all tasks directly
- No specialized quality or security review
- No monitoring
- Telegram bot still works

This is useful for initial testing or emergency situations.

---

## 2.5 Directory Structure (All Machines)

Each machine should use the same directory structure for consistency:

```
C:\
└── AI-Team\
    ├── openclaw\           # OpenClaw installation and config
    │   ├── config\         # Configuration files
    │   ├── logs\           # OpenClaw logs
    │   └── data\           # Persistent data
    ├── models\             # Custom model files (if any)
    ├── repos\              # Git repositories (working copies)
    │   ├── project-1\
    │   ├── project-2\
    │   └── ...
    ├── scripts\            # Utility scripts (monitoring, etc.)
    ├── logs\               # System and application logs
    └── temp\               # Temporary working files
```

**Create this structure now on all machines:**

```powershell
$dirs = @(
    "C:\AI-Team\openclaw\config",
    "C:\AI-Team\openclaw\logs",
    "C:\AI-Team\openclaw\data",
    "C:\AI-Team\models",
    "C:\AI-Team\repos",
    "C:\AI-Team\scripts",
    "C:\AI-Team\logs",
    "C:\AI-Team\temp"
)
foreach ($dir in $dirs) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Write-Host "Created: $dir"
}
```

---

Next: [Chapter 03 - OpenClaw Installation](03-openclaw-installation.md)
