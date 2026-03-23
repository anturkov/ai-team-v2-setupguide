# Chapter 17 - Troubleshooting

This chapter covers common issues you may encounter and how to resolve them.

---

## 17.1 Quick Diagnostic Commands

Run these first when something seems wrong:

```powershell
# Check if services are running
ollama list                        # Ollama status
openclaw cluster status            # OpenClaw cluster health
nvidia-smi                         # GPU status

# Check connectivity
ping 192.168.1.106                 # PC1
ping 192.168.1.112                 # PC2
ping 192.168.1.113                 # Laptop

# Check ports
Test-NetConnection -ComputerName 192.168.1.112 -Port 8080
Test-NetConnection -ComputerName 192.168.1.112 -Port 11434

# Check logs
Get-Content C:\AI-Team\openclaw\logs\openclaw.log -Tail 50
Get-Content C:\AI-Team\logs\monitoring.log -Tail 20
```

---

## 17.2 Common Issues and Solutions

### Issue 1: "ollama: command not found"

**Symptoms**: Running `ollama` in PowerShell gives an error.

**Cause**: Ollama is not in the system PATH.

**Solution**:
```powershell
# Find where Ollama is installed
Get-ChildItem -Path "C:\Users\$env:USERNAME\AppData\Local\Programs" -Filter "ollama.exe" -Recurse -ErrorAction SilentlyContinue
Get-ChildItem -Path "C:\Program Files" -Filter "ollama.exe" -Recurse -ErrorAction SilentlyContinue

# Add to PATH (replace with actual path found above)
$ollamaPath = "C:\Users\$env:USERNAME\AppData\Local\Programs\Ollama"
[System.Environment]::SetEnvironmentVariable("Path", "$env:Path;$ollamaPath", "Machine")

# Restart PowerShell and try again
```

---

### Issue 2: "CUDA out of memory"

**Symptoms**: Model fails to load with a CUDA memory error.

**Cause**: Not enough VRAM for the model.

**Solutions**:

```powershell
# Option 1: Unload other models first
ollama stop coordinator
ollama stop senior-engineer-1

# Option 2: Use a smaller quantization
ollama pull qwen2.5-coder:32b-instruct-q3_K_M  # Q3 instead of Q4

# Option 3: Reduce GPU layers (more CPU offloading)
# In the Modelfile:
# PARAMETER num_gpu 20     # Only load 20 layers on GPU

# Option 4: Reduce context length
# In the Modelfile:
# PARAMETER num_ctx 2048   # Shorter context uses less VRAM

# Check current VRAM usage
nvidia-smi
```

---

### Issue 3: Machines Can't Communicate

**Symptoms**: `openclaw cluster status` shows nodes as OFFLINE, pings fail.

**Cause**: Network or firewall issues.

**Solutions**:

```powershell
# Step 1: Verify network
ipconfig   # Check your IP address
ping 192.168.1.112   # Ping the other machine

# Step 2: Check Windows Firewall
Get-NetFirewallRule -DisplayName "*OpenClaw*" | Format-Table Name, Enabled, Direction, Action

# Step 3: Add firewall rules if missing
New-NetFirewallRule -DisplayName "OpenClaw" -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow
New-NetFirewallRule -DisplayName "Ollama" -Direction Inbound -Protocol TCP -LocalPort 11434 -Action Allow

# Step 4: Disable firewall temporarily (for testing only)
# Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
# WARNING: Re-enable after testing!
# Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True

# Step 5: Check if the service is listening
netstat -an | Select-String "8080"
netstat -an | Select-String "11434"
```

---

### Issue 4: Ollama Not Responding

**Symptoms**: `ollama list` hangs or returns an error.

**Cause**: Ollama service crashed or isn't running.

**Solutions**:

```powershell
# Check if Ollama process is running
Get-Process ollama -ErrorAction SilentlyContinue

# Kill any zombie processes
taskkill /f /im ollama.exe 2>$null
taskkill /f /im ollama_runners.exe 2>$null

# Wait and restart
Start-Sleep -Seconds 3
Start-Process "ollama" -ArgumentList "serve" -WindowStyle Hidden

# Wait for startup
Start-Sleep -Seconds 5

# Verify
ollama list
```

---

### Issue 5: Telegram Bot Not Responding

**Symptoms**: Messages to the bot in Telegram get no response.

**Cause**: Multiple possible causes.

**Solutions**:

```powershell
# Check if Telegram integration is running
openclaw telegram status

# Check the logs for errors
Get-Content C:\AI-Team\openclaw\logs\openclaw.log -Tail 30 | Select-String -Pattern "telegram|error"

# Verify bot token is valid
# Try the token manually:
$token = "YOUR_BOT_TOKEN"
Invoke-RestMethod -Uri "https://api.telegram.org/bot$token/getMe"
# Should return bot info if token is valid

# Restart Telegram integration
openclaw telegram restart

# Common fixes:
# 1. Token expired -> create new bot via BotFather
# 2. Wrong Chat ID -> re-check via /getUpdates
# 3. Network issue -> check outbound HTTPS (port 443)
# 4. Bot was stopped -> /start in BotFather
```

---

### Issue 6: Model Responses Are Very Slow

**Symptoms**: Models take > 60 seconds to respond.

**Cause**: Model running on CPU instead of GPU, or GPU is throttling.

**Solutions**:

```powershell
# Check if model is using GPU
ollama ps
# Look at the "processor" column: "gpu" = good, "cpu" = slow

# Check GPU utilization during inference
nvidia-smi -l 2
# If GPU-Util stays at 0% during inference, the model is on CPU

# Force GPU usage
[System.Environment]::SetEnvironmentVariable("OLLAMA_NUM_GPU", "999", "Machine")

# Check GPU temperature (throttling above ~85C)
nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader

# If temperature is high:
# 1. Check fan speed and cooling
# 2. Reduce power limit: nvidia-smi -pl 300
# 3. Improve case airflow
```

---

### Issue 7: GitHub Push Fails

**Symptoms**: `openclaw github push` or `git push` returns an error.

**Cause**: Authentication or permission issues.

**Solutions**:

```powershell
# Test SSH connection
ssh -T git@github.com

# If "Permission denied":
# 1. Check SSH key is added to GitHub
Get-Content "$env:USERPROFILE\.ssh\id_ed25519_github.pub"
# 2. Copy this and add to github.com/settings/keys

# If "Host key verification failed":
ssh-keyscan github.com >> "$env:USERPROFILE\.ssh\known_hosts"

# If PAT-related error:
# Check token hasn't expired
openclaw github token-info

# Test with a manual clone
git clone git@github.com:your-org/your-repo.git C:\AI-Team\temp\test-clone
```

---

### Issue 8: OpenClaw Won't Start

**Symptoms**: `openclaw start` or `openclaw service start` fails.

**Solutions**:

```powershell
# Check logs for the error
Get-Content C:\AI-Team\openclaw\logs\openclaw.log -Tail 30

# Common causes:
# 1. Port already in use
netstat -an | Select-String "8080"
# If something else is using port 8080, change OpenClaw's port in config

# 2. Invalid configuration
openclaw config validate

# 3. Data directory permissions
icacls "C:\AI-Team\openclaw\data"
# Ensure your user has Full Control

# 4. Corrupted state file
# Back up and reset state
Copy-Item "C:\AI-Team\openclaw\data" "C:\AI-Team\openclaw\data-backup" -Recurse
Remove-Item "C:\AI-Team\openclaw\data\*" -Force
openclaw init --role coordinator --name "pc1-coordinator" --data-dir "C:\AI-Team\openclaw\data"
```

---

### Issue 9: Models Give Wrong or Incoherent Responses

**Symptoms**: Model responses don't match the role or system prompt.

**Cause**: Custom Modelfile not loaded, or model not using the custom version.

**Solutions**:

```powershell
# Verify the custom model exists
ollama list | Select-String "coordinator"

# If missing, rebuild it
ollama create coordinator -f C:\AI-Team\models\Modelfile-coordinator

# Test with explicit system prompt check
ollama run coordinator "What is your role? List your responsibilities."
# Should respond with coordinator-specific content

# If still wrong: check the Modelfile syntax
Get-Content C:\AI-Team\models\Modelfile-coordinator
```

---

### Issue 10: Disk Space Running Low

**Symptoms**: Models fail to download or operations fail with disk errors.

**Solutions**:

```powershell
# Check disk space
Get-PSDrive C | Select-Object @{N='Free(GB)';E={[math]::Round($_.Free/1GB,2)}}

# Clean up old Ollama model cache
# Models are stored in: C:\Users\<username>\.ollama\models
$ollamaDir = "$env:USERPROFILE\.ollama\models"
Get-ChildItem $ollamaDir -Recurse | Measure-Object -Property Length -Sum |
    Select-Object @{N='TotalGB';E={[math]::Round($_.Sum/1GB,2)}}

# Remove unused models
ollama rm model-name-you-dont-need

# Clean up old logs
Remove-Item C:\AI-Team\logs\*.log.zip -Force

# Clean up temp files
Remove-Item C:\AI-Team\temp\* -Recurse -Force
```

---

## 17.3 Log File Locations

| Log | Path | Contains |
|-----|------|----------|
| OpenClaw | `C:\AI-Team\openclaw\logs\openclaw.log` | Service events, errors, cluster communication |
| Monitoring | `C:\AI-Team\logs\monitoring.log` | Resource metrics snapshots |
| Communication | `C:\AI-Team\logs\communication.log` | Inter-model messages |
| Tasks | `C:\AI-Team\logs\tasks.log` | Task lifecycle events |
| Security | `C:\AI-Team\logs\security.log` | Security alerts and violations |
| Telegram | `C:\AI-Team\logs\telegram.log` | Bot messages and API calls |
| GitHub | `C:\AI-Team\logs\github.log` | Git operations |

### Reading Logs

```powershell
# Tail a log file (see latest entries)
Get-Content C:\AI-Team\openclaw\logs\openclaw.log -Tail 50 -Wait

# Search for errors
Select-String -Path C:\AI-Team\openclaw\logs\openclaw.log -Pattern "ERROR|FATAL"

# Search across all logs
Select-String -Path C:\AI-Team\logs\*.log -Pattern "ERROR" | Sort-Object -Property Line
```

---

## 17.4 Getting Help

If you can't resolve an issue:

1. **Check the logs** - They almost always contain the specific error
2. **Run the health check** - `C:\AI-Team\scripts\health-check.ps1`
3. **Check OpenClaw documentation** - Official docs for your version
4. **Check Ollama documentation** - https://ollama.com/docs
5. **Restart services** - `C:\AI-Team\scripts\restart-all.ps1`
6. **Ask the AI team** - Send `/health` via Telegram for a self-diagnostic

---

Next: [Chapter 18 - Security Restrictions](18-security-restrictions.md)
