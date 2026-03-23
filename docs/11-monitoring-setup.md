# Chapter 11 - Monitoring Setup

This chapter covers setting up resource monitoring across all machines, creating dashboards, and configuring alerts for resource exhaustion.

---

## 11.1 Monitoring Overview

The monitoring system tracks:

- **GPU**: Temperature, utilization, VRAM usage per model
- **CPU**: Per-core utilization across all machines
- **RAM**: System memory usage and model memory footprint
- **Disk**: Free space on all drives
- **Network**: Latency between machines, bandwidth usage
- **Models**: Response times, queue depths, error rates
- **Tasks**: Active tasks, completion rates, bottlenecks

---

## 11.2 PowerShell Monitoring Script

This is the primary monitoring tool that runs on each machine and reports to the monitoring agent.

### Create the Main Monitoring Script

**File**: `C:\AI-Team\scripts\monitor-resources.ps1`

```powershell
<#
.SYNOPSIS
    Resource monitoring script for the AI Development Team
.DESCRIPTION
    Collects GPU, CPU, RAM, and disk metrics and reports them
    to the OpenClaw monitoring agent.
.NOTES
    Run this as a scheduled task every 30 seconds.
#>

param(
    [int]$IntervalSeconds = 30,
    [switch]$Continuous,
    [string]$LogFile = "C:\AI-Team\logs\monitoring.log"
)

function Get-GpuMetrics {
    try {
        $nvidiaSmi = nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total,power.draw --format=csv,noheader,nounits 2>$null
        if ($nvidiaSmi) {
            $parts = $nvidiaSmi -split ","
            return @{
                Name        = $parts[0].Trim()
                TempC       = [int]$parts[1].Trim()
                UtilPercent = [int]$parts[2].Trim()
                VramUsedMB  = [int]$parts[3].Trim()
                VramTotalMB = [int]$parts[4].Trim()
                PowerW      = [double]$parts[5].Trim()
                VramPercent = [math]::Round(([int]$parts[3].Trim() / [int]$parts[4].Trim()) * 100, 1)
            }
        }
    } catch {
        return @{ Error = "nvidia-smi not available" }
    }
}

function Get-CpuMetrics {
    $cpu = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
    $loadPercent = (Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction SilentlyContinue).CounterSamples[0].CookedValue
    return @{
        Name        = $cpu.Name
        Cores       = $cpu.NumberOfCores
        Threads     = $cpu.NumberOfLogicalProcessors
        LoadPercent = [math]::Round($loadPercent, 1)
    }
}

function Get-RamMetrics {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $usedGB = $totalGB - $freeGB
    return @{
        TotalGB     = $totalGB
        UsedGB      = $usedGB
        FreeGB      = $freeGB
        UsedPercent = [math]::Round(($usedGB / $totalGB) * 100, 1)
    }
}

function Get-DiskMetrics {
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -gt 0 }
    $result = @()
    foreach ($drive in $drives) {
        $totalGB = [math]::Round(($drive.Used + $drive.Free) / 1GB, 2)
        $usedGB = [math]::Round($drive.Used / 1GB, 2)
        $freeGB = [math]::Round($drive.Free / 1GB, 2)
        $result += @{
            Drive       = "$($drive.Name):"
            TotalGB     = $totalGB
            UsedGB      = $usedGB
            FreeGB      = $freeGB
            UsedPercent = [math]::Round(($usedGB / $totalGB) * 100, 1)
        }
    }
    return $result
}

function Get-OllamaMetrics {
    try {
        $response = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/ps" -Method GET -TimeoutSec 5 2>$null
        $models = @()
        if ($response.models) {
            foreach ($model in $response.models) {
                $models += @{
                    Name    = $model.name
                    Size    = $model.size
                    VramMB  = [math]::Round($model.size_vram / 1MB, 0)
                }
            }
        }
        return @{ Status = "running"; LoadedModels = $models }
    } catch {
        return @{ Status = "not running"; LoadedModels = @() }
    }
}

function Get-AlertLevel {
    param($Metrics)

    $alerts = @()

    # GPU temperature alerts
    if ($Metrics.Gpu.TempC -ge 90) {
        $alerts += @{ Level = "CRITICAL"; Message = "GPU temperature at $($Metrics.Gpu.TempC)°C" }
    } elseif ($Metrics.Gpu.TempC -ge 80) {
        $alerts += @{ Level = "WARNING"; Message = "GPU temperature at $($Metrics.Gpu.TempC)°C" }
    }

    # VRAM alerts
    if ($Metrics.Gpu.VramPercent -ge 95) {
        $alerts += @{ Level = "CRITICAL"; Message = "VRAM usage at $($Metrics.Gpu.VramPercent)%" }
    } elseif ($Metrics.Gpu.VramPercent -ge 90) {
        $alerts += @{ Level = "WARNING"; Message = "VRAM usage at $($Metrics.Gpu.VramPercent)%" }
    }

    # RAM alerts
    if ($Metrics.Ram.UsedPercent -ge 90) {
        $alerts += @{ Level = "CRITICAL"; Message = "RAM usage at $($Metrics.Ram.UsedPercent)%" }
    } elseif ($Metrics.Ram.UsedPercent -ge 85) {
        $alerts += @{ Level = "WARNING"; Message = "RAM usage at $($Metrics.Ram.UsedPercent)%" }
    }

    # Disk alerts
    foreach ($disk in $Metrics.Disk) {
        if ($disk.FreeGB -lt 5) {
            $alerts += @{ Level = "CRITICAL"; Message = "Disk $($disk.Drive) only $($disk.FreeGB) GB free" }
        } elseif ($disk.FreeGB -lt 10) {
            $alerts += @{ Level = "WARNING"; Message = "Disk $($disk.Drive) only $($disk.FreeGB) GB free" }
        }
    }

    return $alerts
}

function Write-MetricsReport {
    param($Metrics, $Alerts)

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $hostname = $env:COMPUTERNAME

    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  RESOURCE MONITOR - $hostname - $timestamp" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan

    # GPU
    Write-Host ""
    Write-Host "  GPU: $($Metrics.Gpu.Name)" -ForegroundColor White
    $gpuColor = if ($Metrics.Gpu.TempC -ge 80) { "Red" } elseif ($Metrics.Gpu.TempC -ge 70) { "Yellow" } else { "Green" }
    Write-Host "    Temperature:  $($Metrics.Gpu.TempC)°C" -ForegroundColor $gpuColor
    Write-Host "    Utilization:  $($Metrics.Gpu.UtilPercent)%"
    Write-Host "    VRAM:         $($Metrics.Gpu.VramUsedMB) / $($Metrics.Gpu.VramTotalMB) MB ($($Metrics.Gpu.VramPercent)%)"
    Write-Host "    Power:        $($Metrics.Gpu.PowerW) W"

    # CPU
    Write-Host ""
    Write-Host "  CPU: $($Metrics.Cpu.Name)" -ForegroundColor White
    Write-Host "    Load:         $($Metrics.Cpu.LoadPercent)%"
    Write-Host "    Cores/Threads: $($Metrics.Cpu.Cores) / $($Metrics.Cpu.Threads)"

    # RAM
    Write-Host ""
    $ramColor = if ($Metrics.Ram.UsedPercent -ge 85) { "Red" } elseif ($Metrics.Ram.UsedPercent -ge 70) { "Yellow" } else { "Green" }
    Write-Host "  RAM:" -ForegroundColor White
    Write-Host "    Used:         $($Metrics.Ram.UsedGB) / $($Metrics.Ram.TotalGB) GB ($($Metrics.Ram.UsedPercent)%)" -ForegroundColor $ramColor

    # Disk
    Write-Host ""
    Write-Host "  DISK:" -ForegroundColor White
    foreach ($disk in $Metrics.Disk) {
        $diskColor = if ($disk.FreeGB -lt 10) { "Red" } elseif ($disk.FreeGB -lt 30) { "Yellow" } else { "Green" }
        Write-Host "    $($disk.Drive)  $($disk.FreeGB) GB free / $($disk.TotalGB) GB total ($($disk.UsedPercent)% used)" -ForegroundColor $diskColor
    }

    # Ollama
    Write-Host ""
    Write-Host "  OLLAMA:" -ForegroundColor White
    Write-Host "    Status: $($Metrics.Ollama.Status)"
    if ($Metrics.Ollama.LoadedModels.Count -gt 0) {
        foreach ($model in $Metrics.Ollama.LoadedModels) {
            Write-Host "    Loaded: $($model.Name) ($($model.VramMB) MB VRAM)"
        }
    } else {
        Write-Host "    No models currently loaded"
    }

    # Alerts
    if ($Alerts.Count -gt 0) {
        Write-Host ""
        Write-Host "  ALERTS:" -ForegroundColor Red
        foreach ($alert in $Alerts) {
            $alertColor = if ($alert.Level -eq "CRITICAL") { "Red" } else { "Yellow" }
            Write-Host "    [$($alert.Level)] $($alert.Message)" -ForegroundColor $alertColor
        }
    }

    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
}

# Main execution
do {
    $metrics = @{
        Gpu    = Get-GpuMetrics
        Cpu    = Get-CpuMetrics
        Ram    = Get-RamMetrics
        Disk   = Get-DiskMetrics
        Ollama = Get-OllamaMetrics
    }

    $alerts = Get-AlertLevel -Metrics $metrics

    Write-MetricsReport -Metrics $metrics -Alerts $alerts

    # Log to file
    $logEntry = @{
        Timestamp = (Get-Date -Format "o")
        Hostname  = $env:COMPUTERNAME
        Metrics   = $metrics
        Alerts    = $alerts
    } | ConvertTo-Json -Depth 5

    Add-Content -Path $LogFile -Value $logEntry

    # Send alerts to OpenClaw if any
    if ($alerts.Count -gt 0) {
        $alertMsg = ($alerts | ForEach-Object { "[$($_.Level)] $($_.Message)" }) -join "; "
        openclaw message send --to monitoring-agent --content "ALERT from $($env:COMPUTERNAME): $alertMsg" 2>$null
    }

    if ($Continuous) {
        Start-Sleep -Seconds $IntervalSeconds
    }
} while ($Continuous)
```

### Run the Monitoring Script

```powershell
# Run once (quick check)
powershell -ExecutionPolicy Bypass -File C:\AI-Team\scripts\monitor-resources.ps1

# Run continuously (every 30 seconds)
powershell -ExecutionPolicy Bypass -File C:\AI-Team\scripts\monitor-resources.ps1 -Continuous -IntervalSeconds 30
```

---

## 11.3 Set Up Monitoring as a Scheduled Task

So monitoring runs automatically in the background:

**On each machine**, run PowerShell as Administrator:

```powershell
# Create a scheduled task that runs monitoring every minute
$action = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument "-ExecutionPolicy Bypass -File C:\AI-Team\scripts\monitor-resources.ps1"
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 1) -RepetitionDuration (New-TimeSpan -Days 365)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName "AI-Team-Monitor" -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description "AI Team Resource Monitoring"
```

**Verify:**

```powershell
Get-ScheduledTask -TaskName "AI-Team-Monitor" | Select-Object TaskName, State
```

---

## 11.4 OpenClaw Built-in Monitoring

OpenClaw has its own monitoring commands:

```powershell
# View cluster-wide health
openclaw monitor health

# View per-node resource usage
openclaw monitor resources --node pc1-coordinator
openclaw monitor resources --node pc2-worker
openclaw monitor resources --node laptop-monitor

# View model performance metrics
openclaw monitor models

# View message queue statistics
openclaw monitor queue

# View task completion statistics
openclaw monitor tasks --last 24h
```

---

## 11.5 Health Check Script

A quick health check you can run at any time to verify the system is healthy.

**File**: `C:\AI-Team\scripts\health-check.ps1`

```powershell
<#
.SYNOPSIS
    Quick health check for the AI Development Team infrastructure
#>

Write-Host ""
Write-Host "=== AI Team Health Check ===" -ForegroundColor Cyan
Write-Host ""

$allHealthy = $true

# Check 1: OpenClaw cluster
Write-Host "[1/6] OpenClaw Cluster..." -NoNewline
try {
    $clusterStatus = openclaw cluster status --format json 2>&1 | ConvertFrom-Json
    $onlineNodes = ($clusterStatus.nodes | Where-Object { $_.status -eq "ONLINE" }).Count
    $totalNodes = $clusterStatus.nodes.Count
    if ($onlineNodes -eq $totalNodes) {
        Write-Host " OK ($onlineNodes/$totalNodes nodes online)" -ForegroundColor Green
    } else {
        Write-Host " DEGRADED ($onlineNodes/$totalNodes nodes online)" -ForegroundColor Yellow
        $allHealthy = $false
    }
} catch {
    Write-Host " FAILED (OpenClaw not responding)" -ForegroundColor Red
    $allHealthy = $false
}

# Check 2: Ollama
Write-Host "[2/6] Ollama Service..." -NoNewline
try {
    $ollamaResponse = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -Method GET -TimeoutSec 5
    $modelCount = $ollamaResponse.models.Count
    Write-Host " OK ($modelCount models available)" -ForegroundColor Green
} catch {
    Write-Host " FAILED (Ollama not responding)" -ForegroundColor Red
    $allHealthy = $false
}

# Check 3: GPU
Write-Host "[3/6] GPU Status..." -NoNewline
try {
    $gpuTemp = (nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>$null).Trim()
    if ([int]$gpuTemp -lt 80) {
        Write-Host " OK (${gpuTemp}°C)" -ForegroundColor Green
    } elseif ([int]$gpuTemp -lt 90) {
        Write-Host " WARM (${gpuTemp}°C)" -ForegroundColor Yellow
    } else {
        Write-Host " HOT (${gpuTemp}°C)" -ForegroundColor Red
        $allHealthy = $false
    }
} catch {
    Write-Host " UNKNOWN (nvidia-smi failed)" -ForegroundColor Yellow
}

# Check 4: Disk space
Write-Host "[4/6] Disk Space..." -NoNewline
$cDrive = Get-PSDrive C
$freeGB = [math]::Round($cDrive.Free / 1GB, 1)
if ($freeGB -gt 20) {
    Write-Host " OK (${freeGB} GB free)" -ForegroundColor Green
} elseif ($freeGB -gt 10) {
    Write-Host " LOW (${freeGB} GB free)" -ForegroundColor Yellow
} else {
    Write-Host " CRITICAL (${freeGB} GB free)" -ForegroundColor Red
    $allHealthy = $false
}

# Check 5: Network connectivity
Write-Host "[5/6] Network..." -NoNewline
$targets = @(
    @{ Name = "PC2"; IP = "192.168.1.112" },
    @{ Name = "Laptop"; IP = "192.168.1.113" }
)
$reachable = 0
foreach ($target in $targets) {
    if (Test-Connection -ComputerName $target.IP -Count 1 -Quiet -TimeoutSeconds 3) {
        $reachable++
    }
}
if ($reachable -eq $targets.Count) {
    Write-Host " OK (all machines reachable)" -ForegroundColor Green
} else {
    Write-Host " DEGRADED ($reachable/$($targets.Count) machines reachable)" -ForegroundColor Yellow
    $allHealthy = $false
}

# Check 6: Telegram bot
Write-Host "[6/6] Telegram Bot..." -NoNewline
try {
    $botStatus = openclaw telegram status 2>&1
    if ($botStatus -match "running|active|connected") {
        Write-Host " OK (connected)" -ForegroundColor Green
    } else {
        Write-Host " DISCONNECTED" -ForegroundColor Red
        $allHealthy = $false
    }
} catch {
    Write-Host " UNKNOWN" -ForegroundColor Yellow
}

Write-Host ""
if ($allHealthy) {
    Write-Host "Overall Status: HEALTHY" -ForegroundColor Green
} else {
    Write-Host "Overall Status: ISSUES DETECTED" -ForegroundColor Yellow
}
Write-Host ""
```

### Run:

```powershell
powershell -ExecutionPolicy Bypass -File C:\AI-Team\scripts\health-check.ps1
```

---

## 11.6 Alert Notification Flow

When an alert is triggered:

```
Monitor Script detects issue
        │
        ▼
Sends alert to Monitoring Agent via OpenClaw
        │
        ▼
Monitoring Agent evaluates severity
        │
        ├── WARNING → Logs it, includes in next status report
        │
        └── CRITICAL → Immediately notifies Coordinator
                │
                ▼
        Coordinator sends Telegram alert to human
                │
                ▼
        "🚨 CRITICAL ALERT: GPU temperature at 92°C on PC1.
         Recommendation: Reduce model load or check cooling."
```

---

## 11.7 Monitoring Agent Configuration

The monitoring agent on the Laptop continuously watches all machines:

```yaml
# Add to team.yaml or monitoring config
monitoring:
  check_interval_seconds: 30
  targets:
    - node: "pc1-coordinator"
      checks: ["gpu", "cpu", "ram", "disk", "ollama", "openclaw"]
    - node: "pc2-worker"
      checks: ["gpu", "cpu", "ram", "disk", "ollama", "openclaw"]
    - node: "laptop-monitor"
      checks: ["gpu", "cpu", "ram", "disk", "ollama"]

  thresholds:
    gpu_temp_warning: 80
    gpu_temp_critical: 90
    vram_warning_percent: 90
    vram_critical_percent: 95
    ram_warning_percent: 85
    ram_critical_percent: 90
    disk_warning_gb: 10
    disk_critical_gb: 5
    model_response_warning_seconds: 60
    model_response_critical_seconds: 120

  reporting:
    summary_interval_minutes: 60     # Send health summary every hour
    alert_cooldown_minutes: 5        # Don't repeat same alert within 5 minutes
```

---

## 11.8 Checklist

- [ ] Monitoring script (`monitor-resources.ps1`) created on all machines
- [ ] Script runs correctly and shows GPU, CPU, RAM, disk, Ollama metrics
- [ ] Scheduled task created for automatic monitoring
- [ ] Health check script (`health-check.ps1`) works
- [ ] Alerts trigger correctly for simulated high-usage scenarios
- [ ] OpenClaw monitoring commands work (`openclaw monitor health`)
- [ ] Alert notifications reach the Coordinator and Telegram
- [ ] Log files are being written to `C:\AI-Team\logs\`

---

Next: [Chapter 12 - Security Hardening](12-security-hardening.md)
