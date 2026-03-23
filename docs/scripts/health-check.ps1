<#
.SYNOPSIS
    Quick health check for the AI Development Team infrastructure.
.DESCRIPTION
    Checks all critical services, network connectivity, GPU status,
    disk space, and Telegram bot connectivity.
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File health-check.ps1
#>

Write-Host ""
Write-Host "=== AI Team Health Check ===" -ForegroundColor Cyan
Write-Host "  Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "  Host: $env:COMPUTERNAME"
Write-Host ""

$allHealthy = $true
$warnings = @()

# ---- Check 1: OpenClaw ----
Write-Host "[1/7] OpenClaw Cluster..." -NoNewline
try {
    $clusterOutput = openclaw cluster status 2>&1
    if ($clusterOutput -match "ONLINE") {
        $onlineCount = ([regex]::Matches($clusterOutput, "ONLINE")).Count
        Write-Host " OK ($onlineCount nodes online)" -ForegroundColor Green
    } else {
        Write-Host " DEGRADED" -ForegroundColor Yellow
        $allHealthy = $false
    }
} catch {
    Write-Host " FAILED (OpenClaw not responding)" -ForegroundColor Red
    $allHealthy = $false
}

# ---- Check 2: Ollama ----
Write-Host "[2/7] Ollama Service..." -NoNewline
try {
    $ollamaResponse = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -Method GET -TimeoutSec 5
    $modelCount = if ($ollamaResponse.models) { $ollamaResponse.models.Count } else { 0 }
    Write-Host " OK ($modelCount models available)" -ForegroundColor Green
} catch {
    Write-Host " FAILED (Ollama not responding)" -ForegroundColor Red
    $allHealthy = $false
}

# ---- Check 3: GPU ----
Write-Host "[3/7] GPU Status..." -NoNewline
try {
    $gpuInfo = nvidia-smi --query-gpu=temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>$null
    if ($gpuInfo) {
        $parts = $gpuInfo -split ","
        $temp = [int]$parts[0].Trim()
        $util = [int]$parts[1].Trim()
        $memUsed = [int]$parts[2].Trim()
        $memTotal = [int]$parts[3].Trim()
        $memPercent = [math]::Round(($memUsed / $memTotal) * 100, 0)

        $color = if ($temp -ge 85) { "Red" } elseif ($temp -ge 75) { "Yellow" } else { "Green" }
        Write-Host " OK (${temp}C, ${util}% util, ${memPercent}% VRAM)" -ForegroundColor $color
        if ($temp -ge 80) { $warnings += "GPU temperature is high (${temp}C)" }
    }
} catch {
    Write-Host " UNKNOWN (nvidia-smi failed)" -ForegroundColor Yellow
}

# ---- Check 4: RAM ----
Write-Host "[4/7] System RAM..." -NoNewline
$os = Get-CimInstance -ClassName Win32_OperatingSystem
$totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
$freeGB = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
$usedPercent = [math]::Round((($totalGB - $freeGB) / $totalGB) * 100, 0)
$color = if ($usedPercent -ge 90) { "Red" } elseif ($usedPercent -ge 80) { "Yellow" } else { "Green" }
Write-Host " OK (${usedPercent}% used, ${freeGB} GB free)" -ForegroundColor $color
if ($usedPercent -ge 85) {
    $warnings += "RAM usage is high (${usedPercent}%)"
    $allHealthy = $false
}

# ---- Check 5: Disk ----
Write-Host "[5/7] Disk Space..." -NoNewline
$cDrive = Get-PSDrive C
$freeGB = [math]::Round($cDrive.Free / 1GB, 1)
$color = if ($freeGB -lt 10) { "Red" } elseif ($freeGB -lt 30) { "Yellow" } else { "Green" }
Write-Host " OK (${freeGB} GB free on C:)" -ForegroundColor $color
if ($freeGB -lt 10) {
    $warnings += "Disk space critically low (${freeGB} GB)"
    $allHealthy = $false
}

# ---- Check 6: Network ----
Write-Host "[6/7] Network..." -NoNewline
$targets = @(
    @{ Name = "PC1"; IP = "192.168.1.106" },
    @{ Name = "PC2"; IP = "192.168.1.112" },
    @{ Name = "Laptop"; IP = "192.168.1.113" }
)
# Exclude self
$myIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -like "192.168.*" } | Select-Object -First 1).IPAddress
$remoteTargets = $targets | Where-Object { $_.IP -ne $myIP }
$reachable = 0
$unreachable = @()
foreach ($target in $remoteTargets) {
    if (Test-Connection -ComputerName $target.IP -Count 1 -Quiet -TimeoutSeconds 3) {
        $reachable++
    } else {
        $unreachable += $target.Name
    }
}
if ($reachable -eq $remoteTargets.Count) {
    Write-Host " OK (all machines reachable)" -ForegroundColor Green
} else {
    Write-Host " DEGRADED ($($unreachable -join ', ') unreachable)" -ForegroundColor Yellow
    $allHealthy = $false
}

# ---- Check 7: Telegram Bot ----
Write-Host "[7/7] Telegram Bot..." -NoNewline
try {
    $botStatus = openclaw telegram status 2>&1
    if ($botStatus -match "running|active|connected") {
        Write-Host " OK" -ForegroundColor Green
    } else {
        Write-Host " DISCONNECTED" -ForegroundColor Yellow
        $warnings += "Telegram bot is not connected"
    }
} catch {
    Write-Host " UNKNOWN (check manually)" -ForegroundColor Yellow
}

# ---- Summary ----
Write-Host ""
if ($warnings.Count -gt 0) {
    Write-Host "Warnings:" -ForegroundColor Yellow
    foreach ($w in $warnings) {
        Write-Host "  - $w" -ForegroundColor Yellow
    }
    Write-Host ""
}

if ($allHealthy) {
    Write-Host "Overall: HEALTHY" -ForegroundColor Green
} else {
    Write-Host "Overall: ISSUES DETECTED (see above)" -ForegroundColor Yellow
}
Write-Host ""
