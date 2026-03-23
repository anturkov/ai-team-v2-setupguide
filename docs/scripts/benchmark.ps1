<#
.SYNOPSIS
    Benchmark AI model response times.
.DESCRIPTION
    Runs a standard prompt against a specified model multiple times
    and reports average, min, and max response times.
.PARAMETER Model
    The Ollama model name to benchmark (default: coordinator)
.PARAMETER Iterations
    Number of test runs (default: 5)
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File benchmark.ps1 -Model "coordinator" -Iterations 5
    powershell -ExecutionPolicy Bypass -File benchmark.ps1 -Model "quality-agent" -Iterations 3
#>

param(
    [string]$Model = "coordinator",
    [int]$Iterations = 5
)

$prompt = "Write a Python function that checks if a number is prime. Include a docstring and type hints. Return only the code."

Write-Host ""
Write-Host "=== Model Benchmark ===" -ForegroundColor Cyan
Write-Host "  Model:      $Model"
Write-Host "  Iterations: $Iterations"
Write-Host "  Prompt:     $($prompt.Substring(0, [Math]::Min(60, $prompt.Length)))..."
Write-Host ""

# Warm-up run (not counted)
Write-Host "  Warm-up run..." -NoNewline
try {
    $body = @{ model = $Model; prompt = "Say hello."; stream = $false } | ConvertTo-Json
    Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/generate" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 120 | Out-Null
    Write-Host " done" -ForegroundColor Green
} catch {
    Write-Host " failed (model may not be available)" -ForegroundColor Red
    exit 1
}

Write-Host ""

$times = @()
$tokenCounts = @()
$tokenRates = @()

for ($i = 1; $i -le $Iterations; $i++) {
    Write-Host "  Run $i/$Iterations ..." -NoNewline

    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        $body = @{
            model  = $Model
            prompt = $prompt
            stream = $false
        } | ConvertTo-Json

        $response = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/generate" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 300
        $sw.Stop()
        $elapsed = $sw.Elapsed.TotalSeconds

        $tokens = if ($response.eval_count) { $response.eval_count } else { 0 }
        $tokPerSec = if ($tokens -gt 0 -and $elapsed -gt 0) { [math]::Round($tokens / $elapsed, 1) } else { 0 }

        $times += $elapsed
        $tokenCounts += $tokens
        $tokenRates += $tokPerSec

        Write-Host " $([math]::Round($elapsed, 1))s | $tokens tokens | $tokPerSec tok/s" -ForegroundColor White
    } catch {
        $sw.Stop()
        Write-Host " FAILED" -ForegroundColor Red
    }
}

if ($times.Count -gt 0) {
    Write-Host ""
    Write-Host "  Results:" -ForegroundColor Green
    Write-Host "  ────────────────────────────────"
    Write-Host "  Time (avg):      $([math]::Round(($times | Measure-Object -Average).Average, 1))s"
    Write-Host "  Time (min):      $([math]::Round(($times | Measure-Object -Minimum).Minimum, 1))s"
    Write-Host "  Time (max):      $([math]::Round(($times | Measure-Object -Maximum).Maximum, 1))s"
    if ($tokenRates.Count -gt 0 -and ($tokenRates | Measure-Object -Sum).Sum -gt 0) {
        Write-Host "  Tokens/sec (avg): $([math]::Round(($tokenRates | Measure-Object -Average).Average, 1))"
        Write-Host "  Tokens (avg):     $([math]::Round(($tokenCounts | Measure-Object -Average).Average, 0))"
    }
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "  No successful runs. Check that the model is available." -ForegroundColor Red
}
