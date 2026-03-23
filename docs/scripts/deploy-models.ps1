<#
.SYNOPSIS
    Download and deploy AI models for the specified machine.
.DESCRIPTION
    Downloads the appropriate Ollama models and creates custom
    Modelfiles with role-specific system prompts.
.PARAMETER Machine
    Which machine to deploy models on: PC1, PC2, or Laptop
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File deploy-models.ps1 -Machine PC1
.NOTES
    This downloads large files (up to ~35 GB for PC1).
    Ensure you have enough disk space and a stable internet connection.
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("PC1", "PC2", "Laptop")]
    [string]$Machine
)

Write-Host "=== Model Deployment for $Machine ===" -ForegroundColor Cyan
Write-Host ""

# Ensure models directory exists
$modelDir = "C:\AI-Team\models"
if (-not (Test-Path $modelDir)) {
    New-Item -ItemType Directory -Path $modelDir -Force | Out-Null
}

function Deploy-Model {
    param(
        [string]$BaseName,
        [string]$CustomName,
        [string]$ModelfilePath
    )

    Write-Host "  Pulling base model: $BaseName ..." -ForegroundColor Yellow
    ollama pull $BaseName
    if ($LASTEXITCODE -ne 0) {
        Write-Host "    FAILED to pull $BaseName" -ForegroundColor Red
        return
    }
    Write-Host "    Downloaded: $BaseName" -ForegroundColor Green

    if ($ModelfilePath -and (Test-Path $ModelfilePath)) {
        Write-Host "  Creating custom model: $CustomName ..." -ForegroundColor Yellow
        ollama create $CustomName -f $ModelfilePath
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    Created: $CustomName" -ForegroundColor Green
        } else {
            Write-Host "    FAILED to create $CustomName" -ForegroundColor Red
        }
    }
    Write-Host ""
}

switch ($Machine) {
    "PC1" {
        Write-Host "Deploying models for PC1 (Coordinator + Senior Engineers)" -ForegroundColor Cyan
        Write-Host "This will download approximately 35 GB of model data." -ForegroundColor Yellow
        Write-Host ""

        Deploy-Model -BaseName "qwen2.5-coder:32b-instruct-q4_K_M" -CustomName "coordinator" -ModelfilePath "$modelDir\Modelfile-coordinator"
        Deploy-Model -BaseName "deepseek-coder-v2:16b-lite-instruct-q4_K_M" -CustomName "senior-engineer-1" -ModelfilePath "$modelDir\Modelfile-senior-eng-1"
        Deploy-Model -BaseName "codellama:13b-instruct-q4_K_M" -CustomName "senior-engineer-2" -ModelfilePath "$modelDir\Modelfile-senior-eng-2"
    }
    "PC2" {
        Write-Host "Deploying models for PC2 (Quality + Security + Backup)" -ForegroundColor Cyan
        Write-Host "This will download approximately 13 GB of model data." -ForegroundColor Yellow
        Write-Host ""

        Deploy-Model -BaseName "qwen2.5-coder:7b-instruct-q4_K_M" -CustomName "quality-agent" -ModelfilePath "$modelDir\Modelfile-quality-agent"
        Deploy-Model -BaseName "mistral:7b-instruct-q4_K_M" -CustomName "security-agent" -ModelfilePath "$modelDir\Modelfile-security-agent"
        Deploy-Model -BaseName "codellama:7b-instruct-q4_K_M" -CustomName "backup-engineer" -ModelfilePath $null
    }
    "Laptop" {
        Write-Host "Deploying models for Laptop (Monitoring + DevOps)" -ForegroundColor Cyan
        Write-Host "This will download approximately 4 GB of model data." -ForegroundColor Yellow
        Write-Host ""

        Deploy-Model -BaseName "phi3:3.8b-mini-instruct-4k-q4_K_M" -CustomName "monitoring-agent" -ModelfilePath "$modelDir\Modelfile-monitoring-agent"
        Deploy-Model -BaseName "qwen2.5:3b-instruct-q4_K_M" -CustomName "devops-agent" -ModelfilePath "$modelDir\Modelfile-devops-agent"
    }
}

Write-Host "=== Model Deployment Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Installed models:" -ForegroundColor White
ollama list
