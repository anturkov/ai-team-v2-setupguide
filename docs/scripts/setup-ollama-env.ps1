<#
.SYNOPSIS
    Configure Ollama environment variables for the AI Team.
.DESCRIPTION
    Sets Ollama environment variables optimized for each machine role.
    Run with the -Machine parameter to specify which machine you're configuring.
.PARAMETER Machine
    Which machine to configure: PC1, PC2, or Laptop
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File setup-ollama-env.ps1 -Machine PC1
.NOTES
    Requires: Administrator privileges
    Restart Ollama after running this script.
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("PC1", "PC2", "Laptop")]
    [string]$Machine
)

Write-Host "=== Ollama Environment Setup for $Machine ===" -ForegroundColor Cyan
Write-Host ""

# Common settings for all machines
[System.Environment]::SetEnvironmentVariable("OLLAMA_HOST", "0.0.0.0:11434", "Machine")
Write-Host "  Set OLLAMA_HOST = 0.0.0.0:11434" -ForegroundColor Green

switch ($Machine) {
    "PC1" {
        [System.Environment]::SetEnvironmentVariable("OLLAMA_MAX_LOADED_MODELS", "2", "Machine")
        [System.Environment]::SetEnvironmentVariable("OLLAMA_KEEP_ALIVE", "30m", "Machine")
        [System.Environment]::SetEnvironmentVariable("OLLAMA_NUM_GPU", "999", "Machine")
        Write-Host "  Set OLLAMA_MAX_LOADED_MODELS = 2" -ForegroundColor Green
        Write-Host "  Set OLLAMA_KEEP_ALIVE = 30m" -ForegroundColor Green
        Write-Host "  Set OLLAMA_NUM_GPU = 999 (full GPU)" -ForegroundColor Green
    }
    "PC2" {
        [System.Environment]::SetEnvironmentVariable("OLLAMA_MAX_LOADED_MODELS", "2", "Machine")
        [System.Environment]::SetEnvironmentVariable("OLLAMA_KEEP_ALIVE", "15m", "Machine")
        [System.Environment]::SetEnvironmentVariable("OLLAMA_NUM_GPU", "999", "Machine")
        Write-Host "  Set OLLAMA_MAX_LOADED_MODELS = 2" -ForegroundColor Green
        Write-Host "  Set OLLAMA_KEEP_ALIVE = 15m" -ForegroundColor Green
        Write-Host "  Set OLLAMA_NUM_GPU = 999 (full GPU)" -ForegroundColor Green
    }
    "Laptop" {
        [System.Environment]::SetEnvironmentVariable("OLLAMA_MAX_LOADED_MODELS", "1", "Machine")
        [System.Environment]::SetEnvironmentVariable("OLLAMA_KEEP_ALIVE", "10m", "Machine")
        [System.Environment]::SetEnvironmentVariable("OLLAMA_NUM_GPU", "20", "Machine")
        Write-Host "  Set OLLAMA_MAX_LOADED_MODELS = 1" -ForegroundColor Green
        Write-Host "  Set OLLAMA_KEEP_ALIVE = 10m" -ForegroundColor Green
        Write-Host "  Set OLLAMA_NUM_GPU = 20 (limited GPU layers)" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Environment variables set. Restart Ollama to apply:" -ForegroundColor Yellow
Write-Host "  taskkill /f /im ollama.exe" -ForegroundColor White
Write-Host "  Start-Sleep -Seconds 3" -ForegroundColor White
Write-Host "  Start-Process ollama -ArgumentList serve -WindowStyle Hidden" -ForegroundColor White
