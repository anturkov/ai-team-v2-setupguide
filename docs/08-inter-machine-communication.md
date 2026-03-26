# Chapter 08 - Inter-Machine Communication

This chapter covers how the OpenClaw Gateway (in WSL2 on PC1 / ATU-RIG02) communicates with Ollama on PC2 (ATURIG01) and Laptop (LTATU01).

> **TL;DR — It's just HTTP.** The Gateway sends model inference requests to remote Ollama instances via their HTTP API on port 11434. That's it. No webhooks, no nodes, no WebSocket. All agent logic and inter-agent communication happen locally on PC1's Gateway.

---

## 8.1 How It Works

```
PC1 / ATU-RIG02 (192.168.1.106)
┌──────────────────────────────────────────────────────────┐
│  WSL2 (Ubuntu)                                            │
│  ┌────────────────────────────────────────────────────┐  │
│  │  OpenClaw Gateway                                   │  │
│  │                                                     │  │
│  │  coordinator ──┐                                    │  │
│  │  sr-eng-1 ─────┤ agent-to-agent: sessions_send     │  │
│  │  sr-eng-2 ─────┘ (all local, no network)            │  │
│  │                                                     │  │
│  │  quality-agent ────→ HTTP → PC2/ATURIG01:11434      │  │
│  │  security-agent ───→ HTTP → PC2/ATURIG01:11434      │  │
│  │  devops-agent ─────→ HTTP → Laptop/LTATU01:11434    │  │
│  │  monitoring-agent ─→ HTTP → Laptop/LTATU01:11434    │  │
│  └────────────────────────┬───────────────────────────┘  │
│                            │ localhost:11434               │
│  ┌─────────────────────────▼──────────────────────────┐  │
│  │  Ollama (Windows native)                            │  │
│  │  coordinator:latest, senior-eng-1, senior-eng-2     │  │
│  └─────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

There is only **one communication channel** between machines:

### Ollama HTTP API (Port 11434)

The Gateway sends inference requests to remote Ollama via standard HTTP. When the quality-agent needs to generate a response, the Gateway looks up its model (`ollama-pc2/quality-agent:latest`), resolves the provider URL (`http://192.168.1.112:11434`), and makes an HTTP POST to the Ollama API. The response streams back over the same connection.

- **Protocol**: HTTP REST
- **Port**: 11434
- **Direction**: PC1 Gateway → Remote Ollama (outbound only)
- **Config**: `models.providers` in `openclaw.json`

> **No nodes, no WebSocket, no webhooks.** Agent-to-agent communication (`sessions_send`, `sessions_spawn`) happens entirely within the Gateway process on PC1. Only model inference crosses the network.

---

## 8.2 Verifying Ollama Connectivity

Test from **WSL2 on PC1 (ATU-RIG02):**

### Local Ollama (PC1 / ATU-RIG02)

```bash
curl -s http://localhost:11434/api/tags | python3 -m json.tool
```

### Remote Ollama (PC2 / ATURIG01)

```bash
curl -s http://192.168.1.112:11434/api/tags | python3 -m json.tool
```

### Remote Ollama (Laptop / LTATU01)

```bash
curl -s http://192.168.1.113:11434/api/tags | python3 -m json.tool
```

All should return a JSON response listing the models on that machine.

### Test Inference on Remote Ollama

```bash
# Test a model on PC2 (ATURIG01)
curl -s http://192.168.1.112:11434/api/generate \
  -d '{"model":"quality-agent:latest","prompt":"Say hello in one sentence.","stream":false}' \
  | python3 -m json.tool
```

---

## 8.3 Ollama Remote Access Setup

For PC2 (ATURIG01) and Laptop (LTATU01), Ollama must listen on all interfaces (not just localhost).

### On PC2 (ATURIG01) — Windows

Set the environment variable **system-wide**:

```powershell
# PowerShell as Administrator
[Environment]::SetEnvironmentVariable("OLLAMA_HOST", "0.0.0.0", "Machine")
```

Restart Ollama (close the tray icon and reopen, or restart the service):

```powershell
# If Ollama runs as a service
Restart-Service -Name "Ollama"

# Or just restart the Ollama app
```

### On Laptop (LTATU01) — Windows

Same steps:

```powershell
[Environment]::SetEnvironmentVariable("OLLAMA_HOST", "0.0.0.0", "Machine")
```

Restart Ollama.

### Firewall on PC2 and Laptop

Allow inbound connections on port 11434:

```powershell
# Run on PC2 (ATURIG01) and Laptop (LTATU01) in PowerShell as Admin
New-NetFirewallRule -DisplayName "Ollama API" -Direction Inbound -Protocol TCP -LocalPort 11434 -Action Allow
```

---

## 8.4 Provider Configuration in `openclaw.json`

This is configured in [Chapter 06](06-team-configuration.md) as part of each phase. Here's the complete `models.providers` section for reference:

```json
{
  "models": {
    "providers": {
      "ollama": {
        "baseUrl": "http://localhost:11434",
        "apiKey": "ollama",
        "api": "ollama"
      },
      "ollama-pc2": {
        "baseUrl": "http://192.168.1.112:11434",
        "apiKey": "ollama",
        "api": "ollama"
      },
      "ollama-laptop": {
        "baseUrl": "http://192.168.1.113:11434",
        "apiKey": "ollama",
        "api": "ollama"
      }
    }
  }
}
```

### Important Rules

- Use `api: "ollama"` — NOT `api: "openai"`. The native Ollama API handles tool calling correctly.
- Do NOT add `/v1` to the URL. Use `http://host:11434`, NOT `http://host:11434/v1`.
- The `apiKey` can be any non-empty string for Ollama (it doesn't actually authenticate).

---

## 8.5 Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `curl: connection refused` on :11434 | Ollama not listening on all interfaces | Set `OLLAMA_HOST=0.0.0.0` and restart Ollama |
| Timeout on remote Ollama | Firewall blocking port 11434 | Add firewall rule (Section 8.3) |
| Model not found on remote | Model name mismatch | Run `ollama list` on remote machine, verify exact name |
| Provider not discovered | Auto-discovery disabled with explicit config | Manually add provider in `openclaw.json` |
| Tool calling fails | Using `/v1` endpoint | Remove `/v1` from provider URL, use `api: "ollama"` |
| WSL2 can't reach remote | WSL2 networking issue | Verify mirrored mode in `.wslconfig`, try `ping 192.168.1.112` from WSL2 |
| Wrong model used | Per-agent model not set | Check `agents.list[].model.primary` in config |

---

## 8.6 Latency Expectations

| Route | Expected Latency | Notes |
|-------|------------------|-------|
| PC1 Gateway → PC1 Ollama (localhost) | < 1 ms | Loopback |
| PC1 Gateway → PC2 Ollama (LAN) | 1-5 ms | LAN HTTP |
| PC1 Gateway → Laptop Ollama (LAN) | 1-10 ms | Depends on Wi-Fi vs Ethernet |
| Model inference (7B GPU) | 3-15 seconds | Depends on prompt length |
| Model inference (13-16B GPU) | 10-30 seconds | Medium model |
| Model inference (32B GPU) | 15-60 seconds | Large model |

> **The bottleneck is always model inference, not network latency.**

---

## 8.7 Shared Folder (Optional)

If you want all machines to access shared files (project repos, configs, etc.), you can mount a Windows share in WSL2:

### Create a Share on PC1 (ATU-RIG02) — Windows

1. Create a folder: `C:\AI-Team-Shared`
2. Right-click → Properties → Sharing → Share with specific people → Everyone (Read/Write)
3. Note the share path: `\\ATU-RIG02\AI-Team-Shared`

### Mount in WSL2 on PC1

```bash
sudo apt install cifs-utils
sudo mkdir -p /mnt/shared
sudo mount -t cifs -o user=atuadm,vers=3.0 //192.168.1.106/AI-Team-Shared /mnt/shared
```

For persistent mount, add to `/etc/fstab`:

```
//192.168.1.106/AI-Team-Shared /mnt/shared cifs user=atuadm,pass=YOUR_PASSWORD,vers=3.0 0 0
```

### Access from PC2 and Laptop

On PC2 (ATURIG01) and Laptop (LTATU01), map the network drive:

```powershell
net use Z: \\ATU-RIG02\AI-Team-Shared /persistent:yes
```

---

## 8.8 Checklist

- [ ] Ollama on PC2 (ATURIG01) bound to `0.0.0.0:11434`
- [ ] Ollama on Laptop (LTATU01) bound to `0.0.0.0:11434`
- [ ] Firewall rules: port 11434 open on PC2 and Laptop
- [ ] `curl http://192.168.1.112:11434/api/tags` works from WSL2 on PC1
- [ ] `curl http://192.168.1.113:11434/api/tags` works from WSL2 on PC1
- [ ] `models.providers` in `openclaw.json` has all 3 providers configured
- [ ] Test inference on remote Ollama returns valid response
- [ ] (Optional) Shared folder mounted and accessible

---

Next: [Chapter 09 - GitHub Integration](09-github-integration.md)
