# Chapter 15 - Performance Tuning

This chapter covers optimization strategies to get the best performance from your distributed AI team.

---

## 15.1 Model Performance Optimization

### 15.1.1 Quantization Trade-offs

| Quantization | Quality | Speed | VRAM | When to Use |
|-------------|---------|-------|------|-------------|
| Q2_K | Poor | Fastest | Least | Never (too low quality) |
| Q3_K_M | Fair | Fast | Low | Only when VRAM is extremely tight |
| Q4_K_M | Good | Good | Medium | **Recommended default** |
| Q5_K_M | Very Good | Moderate | High | When quality matters and VRAM allows |
| Q6_K | Excellent | Slow | High | Complex reasoning tasks |
| Q8_0 | Near-original | Slowest | Highest | When accuracy is critical |
| FP16 | Original | Slowest | Maximum | Research only, not practical |

**Recommendation**: Use Q4_K_M for all models. It provides the best balance of quality, speed, and VRAM usage.

### 15.1.2 Context Length Optimization

Shorter context = faster responses and less memory:

| Agent | Recommended Context | Why |
|-------|-------------------|-----|
| Coordinator | 8192 tokens | Needs to track multi-step conversations |
| Senior Engineer #1 | 8192 tokens | Architecture docs can be long |
| Senior Engineer #2 | 4096 tokens | Code implementations are focused |
| Quality Agent | 4096 tokens | Reviews are scoped to specific files |
| Security Agent | 4096 tokens | Security checks are targeted |
| DevOps Agent | 4096 tokens | Deployment configs are short |
| Monitoring Agent | 2048 tokens | Status reports are brief |

Set context length in each Modelfile:

```dockerfile
PARAMETER num_ctx 4096
```

### 15.1.3 Temperature Settings

| Agent | Temperature | Why |
|-------|------------|-----|
| Coordinator | 0.3 | Consistent, predictable decisions |
| Senior Engineers | 0.2-0.4 | Reliable code generation |
| Quality Agent | 0.2 | Precise, factual reviews |
| Security Agent | 0.2 | Conservative, thorough analysis |
| DevOps Agent | 0.2 | Exact configuration output |
| Monitoring Agent | 0.1 | Factual metrics reporting |

Lower temperature = more deterministic (better for code). Higher temperature = more creative (rarely needed for development tasks).

---

## 15.2 GPU Optimization

### 15.2.1 CUDA Settings

Set these environment variables on each machine for optimal GPU performance:

```powershell
# Disable GPU power management throttling during inference
[System.Environment]::SetEnvironmentVariable("CUDA_DEVICE_ORDER", "PCI_BUS_ID", "Machine")

# Use TF32 for faster computation on RTX 30xx/40xx
[System.Environment]::SetEnvironmentVariable("NVIDIA_TF32_OVERRIDE", "1", "Machine")
```

### 15.2.2 GPU Power Management

Set your GPU to maximum performance mode:

```powershell
# Set GPU to "Prefer Maximum Performance"
nvidia-smi -pm 1                         # Enable persistent mode
nvidia-smi -pl 350                       # Set power limit (adjust for your GPU)
```

**Recommended power limits:**

| GPU | Default TDP | Recommended Limit | Notes |
|-----|------------|-------------------|-------|
| RTX 4090 | 450W | 350W | Reduces heat with minimal performance loss |
| RTX 2080 Ti | 250W | 230W | Good balance |
| Quadro T2000 | 60W | 60W | Keep at default (laptop) |

### 15.2.3 Fan Curve (Desktop PCs Only)

Ensure adequate cooling to prevent thermal throttling:

- **Idle**: 30-40% fan speed
- **Under load**: 70-100% fan speed
- **Target**: Keep GPU below 80C under sustained load

Use MSI Afterburner or your GPU's software to set a custom fan curve.

---

## 15.3 Model Warm-Up Strategy

### 15.3.1 Pre-Loading Priority Models

After system boot, warm up models in priority order:

```powershell
# Warm-up script (run after boot)
# PC1: Load coordinator first (always needed)
ollama run coordinator "System check. Reply OK." --keepalive 60m

# PC2: Pre-load quality agent (most frequently used)
ollama run quality-agent "System check. Reply OK." --keepalive 30m

# Laptop: Pre-load monitoring agent (always on)
ollama run monitoring-agent "System check. Reply OK." --keepalive 60m
```

### 15.3.2 Keep-Alive Configuration

Control how long models stay in memory after last use:

```powershell
# Models that should stay loaded indefinitely
# (set via API or Modelfile)

# For the coordinator (always loaded):
# Add to Modelfile: PARAMETER keep_alive -1    # Never unload

# For frequently used models:
# PARAMETER keep_alive 30m    # Stay loaded 30 minutes after last use

# For rarely used models:
# PARAMETER keep_alive 5m     # Unload quickly to free VRAM
```

---

## 15.4 Response Time Optimization

### 15.4.1 Prompt Engineering for Speed

Shorter, more focused prompts produce faster responses:

**Slow** (vague, long prompt):
```
Can you please look at this code and tell me everything you think
about it, including any issues, improvements, and general thoughts
about the code quality and style?
```

**Fast** (specific, focused prompt):
```
Review this function for bugs and security issues. List only
critical and high severity findings.
```

### 15.4.2 Parallel Task Execution

When multiple independent sub-tasks exist, run them in parallel:

```
Sequential (slow):
  Task A -> wait -> Task B -> wait -> Task C
  Total: 90 seconds

Parallel (fast):
  Task A ─┐
  Task B ─┼─ wait for all ─> combine results
  Task C ─┘
  Total: 30 seconds (limited by slowest task)
```

The coordinator should identify independent sub-tasks and dispatch them simultaneously.

### 15.4.3 Caching Frequent Responses

For repeated queries (like "check system health"), cache the response:

```yaml
# Caching configuration
caching:
  enabled: true
  ttl_seconds: 300               # Cache responses for 5 minutes
  max_entries: 100
  cacheable_queries:
    - pattern: "health check"
      ttl_seconds: 60            # Health data refreshes more often
    - pattern: "system status"
      ttl_seconds: 60
    - pattern: "list models"
      ttl_seconds: 300
```

---

## 15.5 Network Performance

### 15.5.1 Use Ethernet Over Wi-Fi

| Connection | Latency | Bandwidth | Reliability |
|-----------|---------|-----------|-------------|
| Ethernet (1 Gbps) | < 1ms | 1000 Mbps | Very high |
| Wi-Fi 6 (5 GHz) | 2-10ms | 300-600 Mbps | Good |
| Wi-Fi 5 (2.4 GHz) | 5-30ms | 50-150 Mbps | Fair |

**Recommendation**: Use Ethernet for PC1 and PC2 (they handle the most traffic). Wi-Fi is acceptable for the Laptop (lighter workload).

### 15.5.2 Message Size Optimization

Large messages slow down communication:

```yaml
# Message size limits
messaging:
  max_message_size_kb: 512        # Limit message content
  compress_above_kb: 100          # Compress messages larger than 100KB
  truncate_code_output: true      # Don't send entire file contents
  max_code_lines: 500             # Limit code in messages to 500 lines
```

---

## 15.6 Resource Reservation

Prevent the OS and other applications from starving the AI team:

### 15.6.1 Reserve VRAM

Always leave a buffer for the CUDA runtime and OS:

| GPU | Total VRAM | Reserve | Available for Models |
|-----|-----------|---------|---------------------|
| RTX 4090 | 24,576 MB | 1,024 MB | 23,552 MB |
| RTX 2080 Ti | 11,264 MB | 768 MB | 10,496 MB |
| Quadro T2000 | 4,096 MB | 512 MB | 3,584 MB |

### 15.6.2 Reserve RAM

Keep at least 8 GB free for the OS and background processes:

| Machine | Total RAM | Reserve | Available for Models |
|---------|----------|---------|---------------------|
| PC1 | 64 GB | 8 GB | 56 GB |
| PC2 | 64 GB | 8 GB | 56 GB |
| Laptop | 64 GB | 12 GB | 52 GB (more for OS + display) |

---

## 15.7 Performance Benchmarking

### 15.7.1 Benchmark Script

**File**: `C:\AI-Team\scripts\benchmark.ps1`

```powershell
<#
.SYNOPSIS
    Benchmark AI model response times
#>

param(
    [string]$Model = "coordinator",
    [int]$Iterations = 5
)

$prompt = "Write a Python function that checks if a number is prime. Include docstring and type hints."

Write-Host "Benchmarking model: $Model ($Iterations iterations)" -ForegroundColor Cyan
Write-Host ""

$times = @()
for ($i = 1; $i -le $Iterations; $i++) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    $body = @{
        model = $Model
        prompt = $prompt
        stream = $false
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/generate" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 120

    $sw.Stop()
    $elapsed = $sw.Elapsed.TotalSeconds
    $tokensPerSec = if ($response.eval_count -and $elapsed -gt 0) { [math]::Round($response.eval_count / $elapsed, 1) } else { "N/A" }

    Write-Host "  Run $i : $([math]::Round($elapsed, 1))s ($tokensPerSec tok/s)" -ForegroundColor White
    $times += $elapsed
}

$avg = [math]::Round(($times | Measure-Object -Average).Average, 1)
$min = [math]::Round(($times | Measure-Object -Minimum).Minimum, 1)
$max = [math]::Round(($times | Measure-Object -Maximum).Maximum, 1)

Write-Host ""
Write-Host "Results:" -ForegroundColor Green
Write-Host "  Average: ${avg}s"
Write-Host "  Min:     ${min}s"
Write-Host "  Max:     ${max}s"
```

### Run:

```powershell
powershell -ExecutionPolicy Bypass -File C:\AI-Team\scripts\benchmark.ps1 -Model "coordinator" -Iterations 5
```

### 15.7.2 Expected Performance

| Model | GPU | First Token | Full Response (100 tokens) | Tokens/sec |
|-------|-----|-------------|---------------------------|-----------|
| Coordinator (32B Q4) | RTX 4090 | 2-5s | 10-20s | 15-30 |
| Senior Eng (16B Q4) | RTX 4090 | 1-3s | 5-15s | 20-40 |
| Quality Agent (7B Q4) | RTX 2080 Ti | 1-2s | 3-8s | 25-45 |
| Monitoring (3.8B Q4) | Quadro T2000 | 1-3s | 3-10s | 15-25 |

---

## 15.8 Checklist

- [ ] Models using Q4_K_M quantization (unless specific reason for other)
- [ ] Context lengths set appropriately per agent role
- [ ] Temperature settings tuned for each agent
- [ ] GPU power management configured
- [ ] Critical models pre-warmed after boot
- [ ] Keep-alive settings appropriate per model
- [ ] Ethernet used for PC1 and PC2 (recommended)
- [ ] RAM and VRAM reservations maintained
- [ ] Benchmark script run and baseline recorded
- [ ] Caching enabled for frequent queries

---

Next: [Chapter 16 - Testing & Validation](16-testing-validation.md)
