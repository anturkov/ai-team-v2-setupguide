<#
.SYNOPSIS
    Restart all AI Team services on the local machine.
.DESCRIPTION
    Stops and restarts Ollama and OpenClaw services.
    Use when services are misbehaving or after configuration changes.
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File restart-all.ps1
#>

Write-Host "=== Restarting AI Team Services ===" -ForegroundColor Cyan
Write-Host ""

# ---- Stop Services ----
Write-Host "[1/4] Stopping OpenClaw..." -ForegroundColor Yellow
try {
    openclaw service stop 2>$null
    Write-Host "  OpenClaw stopped" -ForegroundColor Green
} catch {
    Write-Host "  OpenClaw was not running" -ForegroundColor Yellow
}

Write-Host "[2/4] Stopping Ollama..." -ForegroundColor Yellow
taskkill /f /im ollama.exe 2>$null | Out-Null
taskkill /f /im ollama_runners.exe 2>$null | Out-Null
Start-Sleep -Seconds 3
Write-Host "  Ollama stopped" -ForegroundColor Green

# ---- Start Services ----
Write-Host "[3/4] Starting Ollama..." -ForegroundColor Yellow
Start-Process "ollama" -ArgumentList "serve" -WindowStyle Hidden
Start-Sleep -Seconds 5

# Verify Ollama
$ollamaReady = $false
for ($i = 0; $i -lt 6; $i++) {
    try {
        Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -TimeoutSec 5 | Out-Null
        $ollamaReady = $true
        break
    } catch {
        Start-Sleep -Seconds 2
    }
}

if ($ollamaReady) {
    Write-Host "  Ollama: RUNNING" -ForegroundColor Green
} else {
    Write-Host "  Ollama: FAILED TO START (check logs)" -ForegroundColor Red
    Write-Host "  Try running 'ollama serve' manually to see errors." -ForegroundColor Yellow
}

Write-Host "[4/4] Starting OpenClaw..." -ForegroundColor Yellow
try {
    openclaw service start 2>$null
    Start-Sleep -Seconds 5
    openclaw cluster status 2>$null | Out-Null
    Write-Host "  OpenClaw: RUNNING" -ForegroundColor Green
} catch {
    Write-Host "  OpenClaw: FAILED TO START (check config)" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Restart Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Run health-check.ps1 to verify everything is working." -ForegroundColor Cyan
