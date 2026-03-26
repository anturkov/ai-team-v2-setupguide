# Chapter 05 - Model Deployment

This chapter covers deploying the AI models on each machine. We use **3 models total** — one per machine, permanently loaded in VRAM. All models are from the **Qwen3 family** for consistent tool-calling behavior.

---

## 5.1 Model Configuration

| Machine | GPU | Model | Ollama Tag | VRAM Usage | Agents Using It |
|---------|-----|-------|-----------|------------|-----------------|
| PC1 (ATU-RIG02) | RTX 4090 24GB | Qwen3-Coder 30B MoE | `qwen3-coder:30b-a3b` | ~21GB | Coordinator, Senior Engineer 2 |
| PC2 (ATURIG01) | RTX 2080 Ti 11GB | Qwen3 14B | `qwen3:14b` | ~10GB | Senior Engineer 1, Quality Agent |
| Laptop (LTATU01) | Quadro T2000 4GB | Qwen3 4B | `qwen3:4b` | ~3GB | Security Agent, DevOps, Monitoring |

### Why These Models

**Qwen3-Coder 30B MoE** (`qwen3-coder:30b-a3b`):
- 30B total parameters but only **3.3B active per token** (MoE architecture) — fast inference despite large size
- Purpose-built for code generation and agentic tool use
- 256K native context window
- Supports tool calling natively in Ollama
- Perfect for both coordinator (task dispatch) and senior engineer (code writing) roles
- Replaces the old `qwen2.5-coder:32b-instruct-q4_K_M` which lacked tool support

**Qwen3 14B** (`qwen3:14b`):
- 14.8B dense parameters with hybrid thinking mode
- Native tool calling support
- 128K context window
- Strong at architecture design AND code review
- Q4_K_M quantization fits in 11GB VRAM with room for KV cache

**Qwen3 4B** (`qwen3:4b`):
- Smallest Qwen3 model with full tool support
- Hybrid thinking mode (toggles between reasoning and fast response)
- Fits comfortably in 4GB VRAM
- Handles structured tasks (security scans, log parsing, devops commands) well
- Weakest link — complex security analysis should be escalated to PC1

### Why All Qwen3?

Using the same model family across all machines ensures **consistent tool-calling format**. When the coordinator dispatches a tool call to any agent, the schema and response format are identical. Mixed model families (e.g., Qwen + Llama + Mistral) cause subtle differences in how tools are invoked and parsed, leading to hard-to-debug failures.

---

## 5.2 Pull Models

### PC1 (ATU-RIG02) — Windows PowerShell

```powershell
ollama pull qwen3-coder:30b-a3b
```

This downloads ~19GB. Verify:

```powershell
ollama list
# Should show: qwen3-coder:30b-a3b
```

### PC2 (ATURIG01) — Windows PowerShell

```powershell
ollama pull qwen3:14b
```

### Laptop (LTATU01) — Windows PowerShell

```powershell
ollama pull qwen3:4b
```

---

## 5.3 Keep Models Loaded Permanently

> **Critical**: Without this, Ollama unloads models after 5 minutes of inactivity. When OpenClaw tries to use an unloaded model, the agent process may time out and die.

### Set `OLLAMA_KEEP_ALIVE=-1` on All Machines

This tells Ollama to **never unload** models from VRAM.

**On PC1 (ATU-RIG02)** — PowerShell as Admin:

```powershell
[Environment]::SetEnvironmentVariable("OLLAMA_KEEP_ALIVE", "-1", "Machine")
```

**On PC2 (ATURIG01)** — same:

```powershell
[Environment]::SetEnvironmentVariable("OLLAMA_KEEP_ALIVE", "-1", "Machine")
```

**On Laptop (LTATU01)** — same:

```powershell
[Environment]::SetEnvironmentVariable("OLLAMA_KEEP_ALIVE", "-1", "Machine")
```

**Restart Ollama** on each machine after setting the variable (close tray icon, reopen, or restart service).

### Verify Models Stay Loaded

After pulling the model, run it once to load it into VRAM:

```powershell
# On each machine, run the respective model once
ollama run qwen3-coder:30b-a3b "Say hello" --keepalive -1
```

Then check:

```powershell
ollama ps
```

You should see `UNTIL: Forever` in the output. If it says `UNTIL: 5m` or similar, the environment variable isn't taking effect — check that you restarted Ollama.

---

## 5.4 Performance Tuning — PC1 (ATU-RIG02)

Since PC1 runs only ONE model on a 24GB RTX 4090, we can maximize its performance.

### Ollama Environment Variables

Set these on PC1 (PowerShell as Admin):

```powershell
# Keep model loaded forever
[Environment]::SetEnvironmentVariable("OLLAMA_KEEP_ALIVE", "-1", "Machine")

# Enable Flash Attention (faster inference, less VRAM for attention)
[Environment]::SetEnvironmentVariable("OLLAMA_FLASH_ATTENTION", "1", "Machine")

# Allow 2 parallel requests (Coordinator + Senior Eng 2 can query simultaneously)
[Environment]::SetEnvironmentVariable("OLLAMA_NUM_PARALLEL", "2", "Machine")

# Max queued requests
[Environment]::SetEnvironmentVariable("OLLAMA_MAX_QUEUE", "10", "Machine")

# KV cache quantization (saves VRAM, allows more context)
[Environment]::SetEnvironmentVariable("OLLAMA_KV_CACHE_TYPE", "q8_0", "Machine")

# All layers on GPU (no CPU offloading)
[Environment]::SetEnvironmentVariable("OLLAMA_GPU_LAYERS", "999", "Machine")
```

Restart Ollama after setting all variables.

### Context Window Recommendation

With `qwen3-coder:30b-a3b` at Q4_K_M (~21GB weights) and `OLLAMA_NUM_PARALLEL=2`:
- **Recommended**: `num_ctx=8192` — reliable with parallel requests, ~2GB KV cache
- **Maximum**: `num_ctx=16384` — only if running single agent at a time
- **Do NOT** set to 32K+ — will cause out-of-memory errors

Set context window in the Modelfile (see Section 5.5).

### Why `OLLAMA_NUM_PARALLEL=2`?

The Coordinator and Senior Engineer 2 both use the same model. With `NUM_PARALLEL=2`, both agents can generate responses simultaneously without queuing. Each parallel slot uses its own KV cache, so VRAM usage = model weights + (num_parallel × context × cache_per_token).

Start with 2. If VRAM allows (check `nvidia-smi`), increase to 3.

---

## 5.5 Performance Tuning — PC2 (ATURIG01)

```powershell
[Environment]::SetEnvironmentVariable("OLLAMA_KEEP_ALIVE", "-1", "Machine")
[Environment]::SetEnvironmentVariable("OLLAMA_FLASH_ATTENTION", "1", "Machine")
[Environment]::SetEnvironmentVariable("OLLAMA_NUM_PARALLEL", "2", "Machine")
[Environment]::SetEnvironmentVariable("OLLAMA_KV_CACHE_TYPE", "q8_0", "Machine")
[Environment]::SetEnvironmentVariable("OLLAMA_GPU_LAYERS", "999", "Machine")
```

Context: `num_ctx=8192` for Qwen3 14B on 11GB VRAM with 2 parallel slots.

---

## 5.6 Performance Tuning — Laptop (LTATU01)

```powershell
[Environment]::SetEnvironmentVariable("OLLAMA_KEEP_ALIVE", "-1", "Machine")
[Environment]::SetEnvironmentVariable("OLLAMA_FLASH_ATTENTION", "1", "Machine")
[Environment]::SetEnvironmentVariable("OLLAMA_NUM_PARALLEL", "1", "Machine")
[Environment]::SetEnvironmentVariable("OLLAMA_KV_CACHE_TYPE", "q4_0", "Machine")
[Environment]::SetEnvironmentVariable("OLLAMA_GPU_LAYERS", "999", "Machine")
```

Context: `num_ctx=4096` for Qwen3 4B on 4GB VRAM. Only 1 parallel slot due to limited VRAM. Use `q4_0` KV cache quantization to save more memory.

---

## 5.7 Ollama Remote Access (PC2 and Laptop)

PC2 and Laptop need to accept HTTP requests from PC1's Gateway.

### Set `OLLAMA_HOST=0.0.0.0` on PC2 and Laptop

**PC2 (ATURIG01):**
```powershell
[Environment]::SetEnvironmentVariable("OLLAMA_HOST", "0.0.0.0", "Machine")
```

**Laptop (LTATU01):**
```powershell
[Environment]::SetEnvironmentVariable("OLLAMA_HOST", "0.0.0.0", "Machine")
```

### Firewall Rules (PC2 and Laptop)

```powershell
# Run on both PC2 and Laptop — PowerShell as Admin
New-NetFirewallRule -DisplayName "Ollama API" -Direction Inbound -Protocol TCP -LocalPort 11434 -Action Allow
```

### Verify from PC1 (WSL2)

```bash
# From WSL2 on PC1 (ATU-RIG02)
curl -s http://192.168.1.112:11434/api/tags  # PC2
curl -s http://192.168.1.113:11434/api/tags  # Laptop
```

Both should return a JSON response with the model list.

---

## 5.8 Verify Tool Calling Works

Test that each model actually supports tool calls:

### From PC1 (WSL2)

```bash
# Test PC1's model (via localhost)
curl -s http://localhost:11434/api/chat -d '{
  "model": "qwen3-coder:30b-a3b",
  "messages": [{"role": "user", "content": "What is 2+2?"}],
  "tools": [{
    "type": "function",
    "function": {
      "name": "calculate",
      "description": "Perform a calculation",
      "parameters": {
        "type": "object",
        "properties": {"expression": {"type": "string"}},
        "required": ["expression"]
      }
    }
  }],
  "stream": false
}' | python3 -m json.tool
```

The response should contain a `tool_calls` array (or the model should attempt to use the tool). If the model ignores the tool and just responds with text, tool calling is not working for that model.

Repeat for PC2 and Laptop with their respective models and URLs.

---

## 5.9 Checklist

### All Machines
- [ ] `OLLAMA_KEEP_ALIVE=-1` set (system environment variable)
- [ ] `OLLAMA_FLASH_ATTENTION=1` set
- [ ] Ollama restarted after setting variables
- [ ] `ollama ps` shows model with `UNTIL: Forever`

### PC1 (ATU-RIG02)
- [ ] `qwen3-coder:30b-a3b` pulled and loaded
- [ ] `OLLAMA_NUM_PARALLEL=2` set
- [ ] `OLLAMA_KV_CACHE_TYPE=q8_0` set
- [ ] Tool calling test passes

### PC2 (ATURIG01)
- [ ] `qwen3:14b` pulled and loaded
- [ ] `OLLAMA_HOST=0.0.0.0` set
- [ ] Firewall rule for port 11434
- [ ] Reachable from PC1 WSL2 (`curl http://192.168.1.112:11434/api/tags`)
- [ ] `OLLAMA_NUM_PARALLEL=2` set
- [ ] Tool calling test passes

### Laptop (LTATU01)
- [ ] `qwen3:4b` pulled and loaded
- [ ] `OLLAMA_HOST=0.0.0.0` set
- [ ] Firewall rule for port 11434
- [ ] Reachable from PC1 WSL2 (`curl http://192.168.1.113:11434/api/tags`)
- [ ] `OLLAMA_NUM_PARALLEL=1` set
- [ ] Tool calling test passes

---

Next: [Chapter 06 - Team Configuration](06-team-configuration.md)
