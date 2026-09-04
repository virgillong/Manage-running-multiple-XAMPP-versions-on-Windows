param (
    [string]$Message = "Alert message",
    [string]$Title = "Alert",
    [string]$Buttons = "OK"
)
# Load the necessary assemblies for Windows Forms
Add-Type -AssemblyName "System.Windows.Forms"
Add-Type -AssemblyName "System.Drawing"

# Default path fallback for rootDir
if (-not $env:rootDir) {
    $env:rootDir = (Resolve-Path "$PSScriptRoot\..").Path
}
$rootDir = $env:rootDir 

    # Load theme and initialize
 $themeFile = Join-Path $env:rootDir "data\theme.txt"
 if (Test-Path $themeFile) {
    $currentMode = (Get-Content $themeFile -Raw).Trim()
 } else {
    $currentMode = "light"  # default mode
 }
# Write-Host "Alert.ps1 loaded in process $PID"

Import-Module (Join-Path $env:rootDir "etc\includes\UIHelpers.psm1") -Force
# Example usage
# Show-Alert -Message "Please fill in all required fields and select exactly 2 files." -Mode $currentMode
# $result = Show-Alert -Message "Do you want to overwrite the existing backup?" -Buttons YesNo -Title "Confirm Overwrite" -Mode "Dark"
Import-Module (Join-Path $env:rootDir "etc\includes\alert.psm1") -Force

# Call the function and write the result to stdout
# --------------------------------------------------------
# Only execute the alert if the script is run directly from batch,
# not when dot-sourced (executed from another powershell script)
# --------------------------------------------------------
$output = Show-Alert -Message $Message -Title $Title -Buttons $Buttons
Write-Output $output
