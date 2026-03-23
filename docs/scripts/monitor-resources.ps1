<#
.SYNOPSIS
    Resource monitoring script for the AI Development Team.
.DESCRIPTION
    Collects GPU, CPU, RAM, disk, and Ollama metrics.
    Can run once or continuously at a specified interval.
    Sends alerts to OpenClaw monitoring agent on threshold violations.
.PARAMETER IntervalSeconds
    How often to collect metrics (default: 30 seconds)
.PARAMETER Continuous
    Run continuously instead of once
.PARAMETER LogFile
    Path to the log file (default: C:\AI-Team\logs\monitoring.log)
.EXAMPLE
    # Run once
    powershell -ExecutionPolicy Bypass -File monitor-resources.ps1

    # Run continuously every 30 seconds
    powershell -ExecutionPolicy Bypass -File monitor-resources.ps1 -Continuous -IntervalSeconds 30
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
    $loadPercent = 0
    try {
        $loadPercent = (Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction SilentlyContinue).CounterSamples[0].CookedValue
    } catch { }
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
    $usedGB = [math]::Round($totalGB - $freeGB, 2)
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
            UsedPercent = if ($totalGB -gt 0) { [math]::Round(($usedGB / $totalGB) * 100, 1) } else { 0 }
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
                    Name   = $model.name
                    VramMB = [math]::Round($model.size_vram / 1MB, 0)
                }
            }
        }
        return @{ Status = "running"; LoadedModels = $models }
    } catch {
        return @{ Status = "not running"; LoadedModels = @() }
    }
}

function Get-Alerts {
    param($Metrics)
    $alerts = @()

    if ($Metrics.Gpu -and -not $Metrics.Gpu.Error) {
        if ($Metrics.Gpu.TempC -ge 90) {
            $alerts += @{ Level = "CRITICAL"; Message = "GPU temperature $($Metrics.Gpu.TempC)C" }
        } elseif ($Metrics.Gpu.TempC -ge 80) {
            $alerts += @{ Level = "WARNING"; Message = "GPU temperature $($Metrics.Gpu.TempC)C" }
        }
        if ($Metrics.Gpu.VramPercent -ge 95) {
            $alerts += @{ Level = "CRITICAL"; Message = "VRAM usage $($Metrics.Gpu.VramPercent)%" }
        } elseif ($Metrics.Gpu.VramPercent -ge 90) {
            $alerts += @{ Level = "WARNING"; Message = "VRAM usage $($Metrics.Gpu.VramPercent)%" }
        }
    }

    if ($Metrics.Ram.UsedPercent -ge 90) {
        $alerts += @{ Level = "CRITICAL"; Message = "RAM usage $($Metrics.Ram.UsedPercent)%" }
    } elseif ($Metrics.Ram.UsedPercent -ge 85) {
        $alerts += @{ Level = "WARNING"; Message = "RAM usage $($Metrics.Ram.UsedPercent)%" }
    }

    foreach ($disk in $Metrics.Disk) {
        if ($disk.FreeGB -lt 5) {
            $alerts += @{ Level = "CRITICAL"; Message = "Disk $($disk.Drive) only $($disk.FreeGB) GB free" }
        } elseif ($disk.FreeGB -lt 10) {
            $alerts += @{ Level = "WARNING"; Message = "Disk $($disk.Drive) only $($disk.FreeGB) GB free" }
        }
    }

    return $alerts
}

function Show-Report {
    param($Metrics, $Alerts)

    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host ""
    Write-Host "=== RESOURCE MONITOR - $env:COMPUTERNAME - $ts ===" -ForegroundColor Cyan

    # GPU
    if ($Metrics.Gpu -and -not $Metrics.Gpu.Error) {
        $gc = if ($Metrics.Gpu.TempC -ge 80) { "Red" } elseif ($Metrics.Gpu.TempC -ge 70) { "Yellow" } else { "Green" }
        Write-Host "  GPU: $($Metrics.Gpu.Name)" -ForegroundColor White
        Write-Host "    Temp: $($Metrics.Gpu.TempC)C | Util: $($Metrics.Gpu.UtilPercent)% | VRAM: $($Metrics.Gpu.VramUsedMB)/$($Metrics.Gpu.VramTotalMB) MB ($($Metrics.Gpu.VramPercent)%) | Power: $($Metrics.Gpu.PowerW)W" -ForegroundColor $gc
    }

    # CPU
    Write-Host "  CPU: $($Metrics.Cpu.LoadPercent)% load ($($Metrics.Cpu.Cores) cores / $($Metrics.Cpu.Threads) threads)"

    # RAM
    $rc = if ($Metrics.Ram.UsedPercent -ge 85) { "Red" } elseif ($Metrics.Ram.UsedPercent -ge 70) { "Yellow" } else { "Green" }
    Write-Host "  RAM: $($Metrics.Ram.UsedGB)/$($Metrics.Ram.TotalGB) GB ($($Metrics.Ram.UsedPercent)%)" -ForegroundColor $rc

    # Disk
    foreach ($disk in $Metrics.Disk) {
        $dc = if ($disk.FreeGB -lt 10) { "Red" } elseif ($disk.FreeGB -lt 30) { "Yellow" } else { "Green" }
        Write-Host "  Disk $($disk.Drive) $($disk.FreeGB) GB free / $($disk.TotalGB) GB ($($disk.UsedPercent)% used)" -ForegroundColor $dc
    }

    # Ollama
    Write-Host "  Ollama: $($Metrics.Ollama.Status)" -NoNewline
    if ($Metrics.Ollama.LoadedModels.Count -gt 0) {
        $modelNames = ($Metrics.Ollama.LoadedModels | ForEach-Object { $_.Name }) -join ", "
        Write-Host " | Loaded: $modelNames" -ForegroundColor White
    } else {
        Write-Host ""
    }

    # Alerts
    if ($Alerts.Count -gt 0) {
        Write-Host "  ALERTS:" -ForegroundColor Red
        foreach ($a in $Alerts) {
            $ac = if ($a.Level -eq "CRITICAL") { "Red" } else { "Yellow" }
            Write-Host "    [$($a.Level)] $($a.Message)" -ForegroundColor $ac
        }
    }
}

# ---- Main Loop ----
do {
    $metrics = @{
        Gpu    = Get-GpuMetrics
        Cpu    = Get-CpuMetrics
        Ram    = Get-RamMetrics
        Disk   = Get-DiskMetrics
        Ollama = Get-OllamaMetrics
    }

    $alerts = Get-Alerts -Metrics $metrics
    Show-Report -Metrics $metrics -Alerts $alerts

    # Log to file
    $logDir = Split-Path $LogFile -Parent
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

    $logEntry = @{
        Timestamp = (Get-Date -Format "o")
        Hostname  = $env:COMPUTERNAME
        Gpu       = $metrics.Gpu
        Cpu       = $metrics.Cpu
        Ram       = $metrics.Ram
        Disk      = $metrics.Disk
        Ollama    = $metrics.Ollama
        Alerts    = $alerts
    } | ConvertTo-Json -Depth 5 -Compress

    Add-Content -Path $LogFile -Value $logEntry

    # Send critical alerts to OpenClaw
    $criticals = $alerts | Where-Object { $_.Level -eq "CRITICAL" }
    if ($criticals.Count -gt 0) {
        $alertMsg = ($criticals | ForEach-Object { "[$($_.Level)] $($_.Message)" }) -join "; "
        try {
            openclaw message send --to monitoring-agent --content "CRITICAL ALERT from $($env:COMPUTERNAME): $alertMsg" 2>$null
        } catch { }
    }

    if ($Continuous) {
        Start-Sleep -Seconds $IntervalSeconds
    }
} while ($Continuous)
