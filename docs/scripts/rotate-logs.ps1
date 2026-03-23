<#
.SYNOPSIS
    Rotate and clean up AI Team log files.
.DESCRIPTION
    Compresses logs older than 7 days and deletes archives older than 30 days.
    Schedule this to run daily via Windows Task Scheduler.
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File rotate-logs.ps1
#>

$logDirs = @(
    "C:\AI-Team\logs",
    "C:\AI-Team\openclaw\logs"
)

$compressAfterDays = 7
$deleteAfterDays = 30

Write-Host "=== Log Rotation ===" -ForegroundColor Cyan
Write-Host "  Compress after: $compressAfterDays days"
Write-Host "  Delete after:   $deleteAfterDays days"
Write-Host ""

foreach ($logDir in $logDirs) {
    if (-not (Test-Path $logDir)) { continue }

    Write-Host "Processing: $logDir" -ForegroundColor White

    # Compress old log files
    $logsToCompress = Get-ChildItem -Path $logDir -Filter "*.log" | Where-Object {
        $_.LastWriteTime -lt (Get-Date).AddDays(-$compressAfterDays)
    }

    foreach ($log in $logsToCompress) {
        $zipPath = "$($log.FullName).zip"
        try {
            Compress-Archive -Path $log.FullName -DestinationPath $zipPath -Force
            Remove-Item $log.FullName -Force
            Write-Host "  Compressed: $($log.Name)" -ForegroundColor Green
        } catch {
            Write-Host "  Failed to compress: $($log.Name) - $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    # Delete old archives
    $archivesToDelete = Get-ChildItem -Path $logDir -Filter "*.zip" | Where-Object {
        $_.LastWriteTime -lt (Get-Date).AddDays(-$deleteAfterDays)
    }

    foreach ($archive in $archivesToDelete) {
        try {
            Remove-Item $archive.FullName -Force
            Write-Host "  Deleted: $($archive.Name)" -ForegroundColor Yellow
        } catch {
            Write-Host "  Failed to delete: $($archive.Name)" -ForegroundColor Red
        }
    }

    if ($logsToCompress.Count -eq 0 -and $archivesToDelete.Count -eq 0) {
        Write-Host "  Nothing to rotate" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "Log rotation complete." -ForegroundColor Green
