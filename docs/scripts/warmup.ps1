<#
.SYNOPSIS
    Warm up the AI Team models after system boot.
.DESCRIPTION
    Pre-loads critical models into GPU memory so the first real
    request is fast. Run this after all services are started.
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File warmup.ps1
#>

Write-Host "=== AI Team Warm-Up Sequence ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Verify cluster
Write-Host "[1/4] Checking cluster health..." -ForegroundColor Yellow
try {
    openclaw cluster status 2>&1 | Out-Null
    Write-Host "  Cluster: OK" -ForegroundColor Green
} catch {
    Write-Host "  Cluster: NOT READY - ensure OpenClaw is running on all machines" -ForegroundColor Red
    Write-Host "  Continuing with local warm-up only..." -ForegroundColor Yellow
}

# Step 2: Detect which machine we're on based on available models
Write-Host "[2/4] Detecting machine role..." -ForegroundColor Yellow
$models = ollama list 2>$null
$machine = "Unknown"
if ($models -match "coordinator") { $machine = "PC1" }
elseif ($models -match "quality-agent") { $machine = "PC2" }
elseif ($models -match "monitoring-agent") { $machine = "Laptop" }
Write-Host "  Detected: $machine" -ForegroundColor Green

# Step 3: Warm up priority models
Write-Host "[3/4] Warming up priority models..." -ForegroundColor Yellow

function Warm-Model {
    param([string]$ModelName)
    Write-Host "  Loading $ModelName ..." -NoNewline
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $body = @{
            model  = $ModelName
            prompt = "System startup check. Reply with: READY"
            stream = $false
        } | ConvertTo-Json

        $response = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/generate" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 180
        $sw.Stop()
        Write-Host " READY ($([math]::Round($sw.Elapsed.TotalSeconds, 1))s)" -ForegroundColor Green
    } catch {
        $sw.Stop()
        Write-Host " FAILED ($($_.Exception.Message))" -ForegroundColor Red
    }
}

switch ($machine) {
    "PC1" {
        Warm-Model "coordinator"
        # Don't warm Senior Engineers - they swap with coordinator
    }
    "PC2" {
        Warm-Model "quality-agent"
        # Don't warm security-agent yet - let quality-agent settle
    }
    "Laptop" {
        Warm-Model "monitoring-agent"
    }
    default {
        Write-Host "  Could not detect machine role. Skipping warm-up." -ForegroundColor Yellow
    }
}

# Step 4: Verify model availability
Write-Host "[4/4] Checking model availability..." -ForegroundColor Yellow
$loadedModels = ollama ps 2>$null
if ($loadedModels) {
    Write-Host "  Currently loaded models:" -ForegroundColor White
    Write-Host $loadedModels
} else {
    Write-Host "  No models currently loaded (they will load on first request)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Warm-Up Complete ===" -ForegroundColor Cyan
Write-Host "Send tasks via Telegram to begin working."
