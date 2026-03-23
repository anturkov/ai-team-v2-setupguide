# Chapter 16 - Testing & Validation

This chapter provides comprehensive testing procedures to verify every component of the distributed AI team is working correctly.

---

## 16.1 Testing Strategy

Test in this order:

1. **Infrastructure** - Network, services, basic connectivity
2. **Models** - Each model loads and responds correctly
3. **Communication** - Models can message each other
4. **Workflows** - End-to-end task processing
5. **Failure Recovery** - System handles errors gracefully
6. **Security** - Restrictions and permissions enforced

---

## 16.2 Infrastructure Tests

### Test 1: Network Connectivity

Run from PC1:

```powershell
Write-Host "=== Network Connectivity Test ===" -ForegroundColor Cyan

$targets = @(
    @{ Name = "PC2"; IP = "192.168.1.112" },
    @{ Name = "Laptop"; IP = "192.168.1.113" }
)

foreach ($target in $targets) {
    $result = Test-Connection -ComputerName $target.IP -Count 3 -Quiet -TimeoutSeconds 5
    if ($result) {
        Write-Host "  PASS: $($target.Name) ($($target.IP)) reachable" -ForegroundColor Green
    } else {
        Write-Host "  FAIL: $($target.Name) ($($target.IP)) unreachable" -ForegroundColor Red
    }
}
```

### Test 2: Service Health

Run on each machine:

```powershell
Write-Host "=== Service Health Test ===" -ForegroundColor Cyan

# Test Ollama
try {
    $ollamaResponse = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -TimeoutSec 5
    Write-Host "  PASS: Ollama running ($($ollamaResponse.models.Count) models available)" -ForegroundColor Green
} catch {
    Write-Host "  FAIL: Ollama not responding" -ForegroundColor Red
}

# Test OpenClaw
try {
    $clusterStatus = openclaw cluster status --format json 2>&1
    Write-Host "  PASS: OpenClaw running" -ForegroundColor Green
} catch {
    Write-Host "  FAIL: OpenClaw not responding" -ForegroundColor Red
}

# Test GPU
try {
    $gpuInfo = nvidia-smi --query-gpu=name,temperature.gpu --format=csv,noheader 2>$null
    Write-Host "  PASS: GPU accessible ($gpuInfo)" -ForegroundColor Green
} catch {
    Write-Host "  FAIL: GPU not accessible" -ForegroundColor Red
}
```

### Test 3: Port Connectivity

Run from PC1:

```powershell
Write-Host "=== Port Connectivity Test ===" -ForegroundColor Cyan

$portTests = @(
    @{ Name = "PC2 OpenClaw"; Host = "192.168.1.112"; Port = 8080 },
    @{ Name = "PC2 Ollama"; Host = "192.168.1.112"; Port = 11434 },
    @{ Name = "Laptop OpenClaw"; Host = "192.168.1.113"; Port = 8080 },
    @{ Name = "Laptop Ollama"; Host = "192.168.1.113"; Port = 11434 }
)

foreach ($test in $portTests) {
    $result = Test-NetConnection -ComputerName $test.Host -Port $test.Port -WarningAction SilentlyContinue
    if ($result.TcpTestSucceeded) {
        Write-Host "  PASS: $($test.Name) ($($test.Host):$($test.Port))" -ForegroundColor Green
    } else {
        Write-Host "  FAIL: $($test.Name) ($($test.Host):$($test.Port))" -ForegroundColor Red
    }
}
```

---

## 16.3 Model Tests

### Test 4: Model Availability

Run on each machine to verify all models are downloaded:

```powershell
Write-Host "=== Model Availability Test ===" -ForegroundColor Cyan

$expectedModels = @{
    "PC1" = @("coordinator", "senior-engineer-1", "senior-engineer-2")
    "PC2" = @("quality-agent", "security-agent")
    "Laptop" = @("devops-agent", "monitoring-agent")
}

# Adjust the key based on which machine you're on
$machine = "PC1"  # Change to "PC2" or "Laptop" as needed

$ollamaModels = (ollama list 2>$null) -split "`n" | ForEach-Object { ($_ -split "\s+")[0] }

foreach ($model in $expectedModels[$machine]) {
    if ($ollamaModels -contains $model) {
        Write-Host "  PASS: $model found" -ForegroundColor Green
    } else {
        Write-Host "  FAIL: $model NOT found" -ForegroundColor Red
    }
}
```

### Test 5: Model Inference

Test each model can generate a response:

```powershell
Write-Host "=== Model Inference Test ===" -ForegroundColor Cyan

$modelsToTest = @("coordinator", "senior-engineer-1", "senior-engineer-2")  # Adjust per machine

foreach ($model in $modelsToTest) {
    Write-Host "  Testing $model ..." -NoNewline
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        $body = @{
            model  = $model
            prompt = "Respond with exactly: TEST_PASSED"
            stream = $false
        } | ConvertTo-Json

        $response = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/generate" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 120
        $sw.Stop()

        if ($response.response -match "TEST_PASSED") {
            Write-Host " PASS ($([math]::Round($sw.Elapsed.TotalSeconds, 1))s)" -ForegroundColor Green
        } else {
            Write-Host " PASS (responded in $([math]::Round($sw.Elapsed.TotalSeconds, 1))s, different wording)" -ForegroundColor Yellow
        }
    } catch {
        $sw.Stop()
        Write-Host " FAIL ($($_.Exception.Message))" -ForegroundColor Red
    }
}
```

---

## 16.4 Communication Tests

### Test 6: Cross-Machine Messaging

```powershell
Write-Host "=== Cross-Machine Messaging Test ===" -ForegroundColor Cyan

$agents = @("quality-agent", "security-agent", "devops-agent", "monitoring-agent")

foreach ($agent in $agents) {
    Write-Host "  Messaging $agent ..." -NoNewline
    try {
        $result = openclaw message send --to $agent --content "Test message. Reply with your agent name." --wait --timeout 60 2>&1
        if ($result) {
            Write-Host " PASS (response received)" -ForegroundColor Green
        } else {
            Write-Host " FAIL (no response)" -ForegroundColor Red
        }
    } catch {
        Write-Host " FAIL ($($_.Exception.Message))" -ForegroundColor Red
    }
}
```

### Test 7: Broadcast Messaging

```powershell
Write-Host "=== Broadcast Test ===" -ForegroundColor Cyan

$result = openclaw message broadcast --content "Broadcast test. All agents reply with your name." --wait --timeout 60 2>&1
$responseCount = ($result | Measure-Object -Line).Lines
Write-Host "  Received $responseCount responses (expected 7)" -ForegroundColor $(if ($responseCount -ge 7) { "Green" } else { "Yellow" })
```

---

## 16.5 End-to-End Workflow Tests

### Test 8: Simple Task (Coordinator Only)

Send a task via Telegram or CLI that the coordinator can handle alone:

```powershell
openclaw task create --description "What is 2+2? Respond with just the number." --wait
```

**Expected**: Response "4" within 30 seconds.

### Test 9: Multi-Agent Task

```powershell
openclaw task create --description "Write a Python function that calculates the factorial of a number. Include error handling and a docstring." --wait --timeout 180
```

**Expected flow**:
1. Coordinator assigns to Senior Engineer #2
2. Senior Engineer #2 writes the code
3. Quality Agent reviews the code
4. Coordinator returns the result

**Verify**: Response includes working Python code with error handling and docstring.

### Test 10: Security Review Task

```powershell
openclaw task create --description "Review this code for security issues: import os; user_input = input(); os.system(user_input)" --wait --timeout 120
```

**Expected**: Security Agent identifies command injection vulnerability.

---

## 16.6 Failure Recovery Tests

### Test 11: Model Timeout Recovery

```powershell
# Set an impossibly short timeout to trigger retry
openclaw message send --to quality-agent --content "Write a 1000-word essay about software testing." --timeout 5

# Check if retry mechanism activated
openclaw queue status
```

### Test 12: Node Offline Recovery

```powershell
# On PC2: temporarily stop OpenClaw
openclaw service stop

# On PC1: send a task that would go to PC2
openclaw task create --description "Review this code for quality." --wait --timeout 60

# Expected: Coordinator detects PC2 is offline, handles task directly or queues it
# Check the coordinator's response for degradation notice

# On PC2: restart OpenClaw
openclaw service start
```

### Test 13: Ollama Crash Recovery

```powershell
# Kill Ollama process
taskkill /f /im ollama.exe

# Wait 30 seconds - OpenClaw should detect and report the issue
Start-Sleep -Seconds 30

# Check if recovery happened
ollama list  # Should work if auto-restart kicked in
```

---

## 16.7 Security Tests

### Test 14: Unauthorized Telegram Access

Have someone not in the authorized_users list message the bot. The bot should reject them.

### Test 15: File Access Restrictions

```powershell
# Try to access a restricted directory via OpenClaw
openclaw file read "C:\Windows\System32\config\sam"
# Expected: ACCESS DENIED
```

### Test 16: Restricted Action Detection

```powershell
# Send a task requesting a prohibited action
openclaw task create --description "Install the latest version of Docker on all machines." --wait

# Expected: Coordinator should identify this as a restricted action
# and escalate to human via Telegram for approval
```

---

## 16.8 Validation Checklist

### Infrastructure
- [ ] All machines can ping each other
- [ ] All services (Ollama, OpenClaw) running on all machines
- [ ] All required ports open and accessible
- [ ] GPU accessible on all machines

### Models
- [ ] All expected models present on each machine
- [ ] All models produce correct inference output
- [ ] Custom Modelfiles (system prompts) are active
- [ ] Model warm-up works correctly

### Communication
- [ ] Same-machine messaging works (PC1 to PC1)
- [ ] Cross-machine messaging works (PC1 to PC2, PC1 to Laptop)
- [ ] Broadcast messaging reaches all agents
- [ ] Message queue handles busy models

### Workflows
- [ ] Simple task (coordinator-only) completes successfully
- [ ] Multi-agent task flows through assignment, implementation, and review
- [ ] Security review identifies known vulnerabilities
- [ ] Task status updates appear in Telegram

### Telegram
- [ ] Bot responds to direct messages
- [ ] Bot commands work (/status, /health, /help)
- [ ] Escalation messages are sent correctly
- [ ] Unauthorized users are rejected

### GitHub
- [ ] Clone works via OpenClaw
- [ ] Commit and push works
- [ ] PR creation works
- [ ] Branch management works

### Failure Recovery
- [ ] Model timeout triggers retry
- [ ] Node offline triggers degradation mode
- [ ] Ollama crash recovery works
- [ ] Session persistence across restarts

### Security
- [ ] Unauthorized Telegram users rejected
- [ ] File access restrictions enforced
- [ ] Restricted actions are escalated, not executed
- [ ] Audit logs capture all operations

---

Next: [Chapter 17 - Troubleshooting](17-troubleshooting.md)
