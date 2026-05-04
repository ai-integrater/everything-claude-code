# Non-interactive cleanup for hung OAuth dispatch sessions.
# Kills non-responding python/node/pwsh processes and quarantines stale token files.
# Run as Admin on Windows PowerShell 5.1+ or PowerShell 7+.

$ErrorActionPreference = "Stop"

$LogFile = Join-Path $PSScriptRoot "process_cleanup_log_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
$QuarantineFolder = Join-Path $PSScriptRoot "Quarantine"
$TokenPatterns = @("token.json", "*.pickle", "credentials.json")

function Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] $Message"
    Write-Host $LogMessage
    Add-Content -Path $LogFile -Value $LogMessage
}

# Step 1: find non-responding python/node/pwsh processes
Log "Step 1: scanning for non-responding python/node/pwsh processes."
$Candidates = Get-Process python, node, pwsh -ErrorAction SilentlyContinue |
    Where-Object { -not $_.Responding }

if (-not $Candidates) {
    Log "No non-responding processes found."
} else {
    $Summary = ($Candidates | ForEach-Object { "$($_.Name) (ID: $($_.Id))" }) -join ", "
    Log "Non-responding processes: $Summary"

    foreach ($Process in $Candidates) {
        try {
            Stop-Process -Id $Process.Id -Force -ErrorAction Stop
            Log "Killed process: $($Process.Name) (ID: $($Process.Id))"
        } catch {
            Log "Failed to kill process: $($Process.Name) (ID: $($Process.Id)) - $_"
        }
    }
}

# Step 2: quarantine stale OAuth token files
Log "Step 2: quarantining OAuth token files matching: $($TokenPatterns -join ', ')."
if (-not (Test-Path -Path $QuarantineFolder)) {
    New-Item -Path $QuarantineFolder -ItemType Directory | Out-Null
    Log "Created quarantine folder: $QuarantineFolder"
}

foreach ($Pattern in $TokenPatterns) {
    $Files = Get-ChildItem -Path $PSScriptRoot -Recurse -Filter $Pattern -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notlike "$QuarantineFolder*" }
    foreach ($File in $Files) {
        try {
            $Destination = Join-Path -Path $QuarantineFolder -ChildPath "$($File.BaseName)_$(Get-Date -Format 'yyyyMMdd_HHmmss')$($File.Extension)"
            Move-Item -Path $File.FullName -Destination $Destination -ErrorAction Stop
            Log "Moved file: $($File.FullName) -> $Destination"
        } catch {
            Log "Failed to move file: $($File.FullName) - $_"
        }
    }
}

Log "Script completed."
Write-Host "Cleanup finished. Log file: $LogFile" -ForegroundColor Green
