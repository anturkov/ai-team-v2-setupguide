<#
.SYNOPSIS
    Create the AI Team directory structure on the local machine.
.DESCRIPTION
    Run this script on EACH machine (PC1, PC2, Laptop) to create the
    standard directory layout used by the AI Development Team.
.NOTES
    Requires: Administrator privileges
    Run with: powershell -ExecutionPolicy Bypass -File setup-directories.ps1
#>

Write-Host "=== AI Team Directory Setup ===" -ForegroundColor Cyan
Write-Host ""

$dirs = @(
    "C:\AI-Team\openclaw\config",
    "C:\AI-Team\openclaw\logs",
    "C:\AI-Team\openclaw\data",
    "C:\AI-Team\models",
    "C:\AI-Team\repos",
    "C:\AI-Team\scripts",
    "C:\AI-Team\logs",
    "C:\AI-Team\temp"
)

foreach ($dir in $dirs) {
    if (Test-Path $dir) {
        Write-Host "  EXISTS: $dir" -ForegroundColor Yellow
    } else {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "  CREATED: $dir" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Directory setup complete." -ForegroundColor Green
Write-Host ""
Write-Host "Directory structure:" -ForegroundColor Cyan
Write-Host "  C:\AI-Team\"
Write-Host "  +-- openclaw\         (OpenClaw installation and config)"
Write-Host "  |   +-- config\       (Configuration files)"
Write-Host "  |   +-- logs\         (OpenClaw logs)"
Write-Host "  |   +-- data\         (Persistent state data)"
Write-Host "  +-- models\           (Custom Ollama Modelfiles)"
Write-Host "  +-- repos\            (Git repositories)"
Write-Host "  +-- scripts\          (Utility and monitoring scripts)"
Write-Host "  +-- logs\             (Application logs)"
Write-Host "  +-- temp\             (Temporary working files)"
