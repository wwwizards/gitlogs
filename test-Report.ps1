# Function to run the report and save output to a file
# Function to run the report and save output to a file
function Run-And-SaveReport {
    param (
        [string]$Lookback,
        [string]$FileName
    )

    Write-Host "`n`n`n----------------------------------------------------------------------------"
    Write-Host "`t ### Executing Report-TimeLogs.ps1 with lookback period: $Lookback"
    Write-Host "----------------------------------------------------------------------------`n`n`n"

    $scriptPath = ".\Report-TimeLogs.ps1"

    if (Test-Path $scriptPath) {
        $output = & $scriptPath -lookback $Lookback
        $output | Out-Host
        $output | Set-Content -Path $FileName
    } else {
        Write-Host "Script $scriptPath not found."
    }
}

# [Rest of the script remains the same]
