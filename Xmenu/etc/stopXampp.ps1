param(
    [string]$xamppDir
)

# Do not globally silence errors while debugging
$ErrorActionPreference = "Continue"
# $ErrorActionPreference = "SilentlyContinue"

$exitCode = 0

# Default path fallback for rootDir
if (-not $env:rootDir) {
    $env:rootDir = (Resolve-Path "$PSScriptRoot\..").Path
}
$rootDir = $env:rootDir 

Write-Host ""
Write-Host "Ensure all resources required by Xampp are available"
Write-Host ""

# ---------------------------------------------------------
# Detect XAMPP Control Panel
# ---------------------------------------------------------
$serviceStopped = $false

$xamppControl = Get-Process `
    -Name "xampp-control" `
    -ErrorAction SilentlyContinue

if ($xamppControl) {

    Write-Host "Found active XAMPP Control Panel ... stopping services"

    # Kill control panel
    Write-Host "Terminating $($xamppControl.Count) active XAMPP Control Panel process(es)"
    
    try {

        Stop-Process `
            -Name "xampp-control" `
            -Force `
            -ErrorAction Stop

        Write-Host "Xampp Control Panel terminated"
    }
    catch {

        Write-Warning "Unable to terminate Xampp Control Panel"
    }
} else {
    Write-Host "Did not find active Xampp Control Panel"
}


# Shutdown services .... Graceful shutdown FIRST
if (Test-Path "$xamppDir\xampp_stop.exe") {

    & "$xamppDir\xampp_stop.exe" | Out-Null
    Start-Sleep -Seconds 3

    $apache = Get-Process httpd  -ErrorAction SilentlyContinue
    $mysql  = Get-Process mysqld -ErrorAction SilentlyContinue

    if (-not $apache -and -not $mysql) {
	Write-Host "SUCCESS: XAMPP services stopped"
	exit $exitCode
    }

    Write-Host "Graceful shutdown incomplete, continuing cleanup..."
}

# ---------------------------------------------------------
# Port Cleanup
# ---------------------------------------------------------


$chkPortsScript = "$rootDir\etc\chkports.ps1"

if (Test-Path $chkPortsScript) {

    & $chkPortsScript "false"

    if (-not $?) {

        $exitCode = 2
    }
}
exit $exitCode