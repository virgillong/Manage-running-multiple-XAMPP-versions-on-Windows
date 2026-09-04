# loadXampp.ps1

param(
    [string]$xamppDir,
    [string]$xamppInstall
)

# Do not globally silence errors while debugging
$ErrorActionPreference = "Continue"
# $ErrorActionPreference = "SilentlyContinue"

# ---------------------------------------------------------
# Defaults
# ---------------------------------------------------------

# Default path fallback for rootDir
if (-not $env:rootDir) {
    $env:rootDir = (Resolve-Path "$PSScriptRoot\..").Path
}
$rootDir = $env:rootDir 
$message = ""
$XamppService = 0
$exitCode = 0

# ---------------------------------------------------------
# Helper: Alert Dialog
# ---------------------------------------------------------
Import-Module (Join-Path $rootDir "etc\includes\alert.psm1") -Force
Import-Module (Join-Path $rootDir "etc\includes\UIHelpers.psm1") -Force

$themeFile = Join-Path $rootDir "data\theme.txt"
$currentMode = Import-ThemeState -themeFile $themeFile

# ---------------------------------------------------------
# Helper: Wait Until
# ---------------------------------------------------------
function Wait-Until {

    param(
        [scriptblock]$Test,
        [string]$Description,
        [int]$Retries = 30,
        [int]$DelaySeconds = 2
    )

    for ($i = 1; $i -le $Retries; $i++) {

        Write-Host ""
        Write-Host "Attempt $i : $Description"

        try {
            if (& $Test) {
        #       Write-Host "Success: $Description"
                return $true
            }
        }
        catch {
            Write-Host "Still waiting..."
        }

        Start-Sleep -Seconds $DelaySeconds
    }

    Write-Host ""
    Write-Host "Timeout waiting for: $Description"
    return $false
}

# ---------------------------------------------------------
# Helper: Wait For Apache
# ---------------------------------------------------------
function Wait-ForApache {

    param([string]$Url = "http://localhost")

    return Wait-Until `
        -Description "Waiting for Apache HTTP response" `
        -Retries 30 `
        -DelaySeconds 2 `
        -Test {

            try {
                $response = Invoke-WebRequest `
                    -Uri $Url `
                    -UseBasicParsing `
                    -TimeoutSec 5

                return $response.StatusCode -eq 200
            }
            catch {
                return $false
            }
        }
}

# ---------------------------------------------------------
# Helper: Wait For MySQL
# ---------------------------------------------------------
function Wait-ForMySql {

    param([string]$xamppDir)

    $mysql = "$xamppDir\mysql\bin\mysql.exe"

    return Wait-Until `
        -Description "Waiting for MySQL readiness" `
        -Retries 60 `
        -DelaySeconds 2 `
        -Test {

            try {
                $out = & $mysql `
                    -h 127.0.0.1 `
                    -u root `
                    -e "SELECT 1;" `
                    2>$null

                return $LASTEXITCODE -eq 0 -and $out
            }
            catch {
                return $false
            }
        }
}

# ---------------------------------------------------------
# Helper: Validate PHP
# ---------------------------------------------------------
function Test-Php {

    param([string]$xamppDir)

    return Wait-Until `
        -Description "Validating PHP" `
        -Retries 5 `
        -DelaySeconds 1 `
        -Test {
            & "$xamppDir\php\php.exe" -v *> $null
            return $LASTEXITCODE -eq 0
        }
}

# ---------------------------------------------------------
# Function: Start-Xampp
# ---------------------------------------------------------
function Start-Xampp {

    param(
        [string]$xamppDir,
        [string]$xamppDirCur
    )

    # -----------------------------------------------------
    # Verify XAMPP exists
    # -----------------------------------------------------
    if (-not (Test-Path $xamppDir)) {

        return [pscustomobject]@{
            ExitCode     = 1
            Message      = "Cannot find $xamppDir"
            XamppService = 0
        }
    }

    # Start-Sleep -Seconds 3

    # -----------------------------------------------------
    # Stop existing XAMPP (safe cleanup)
    # -----------------------------------------------------
    & "$rootDir\etc\stopXampp.ps1" -xamppDir $xamppDirCur

    # -----------------------------------------------------
    # Start Apache
    # -----------------------------------------------------
    Write-Host ""
    Write-Host "Starting Apache..."

    Start-Process `
        -FilePath "$xamppDir\apache_start.bat" `
        -WindowStyle Hidden

    if (-not (Wait-ForApache)) {

        return [pscustomobject]@{
            ExitCode     = 2
            Message      = "Apache failed to become ready"
            XamppService = 1
        }
    } else {
	Write-Host "Success: Apache is ready"
    }

    # -----------------------------------------------------
    # Start MySQL
    # -----------------------------------------------------
    Write-Host ""
    Write-Host "Starting MySQL..."

    Start-Process `
        -FilePath "$xamppDir\mysql_start.bat" `
        -WindowStyle Hidden

    # DO NOT trust process check — only readiness
    if (-not (Wait-ForMySql -xamppDir $xamppDir)) {

        return [pscustomobject]@{
            ExitCode     = 2
            Message      = "MySQL failed to become ready (check logs)"
            XamppService = 2
        }
    } else {
	Write-Host "Success: MySQL is ready"
    }

    # -----------------------------------------------------
    # Validate PHP
    # -----------------------------------------------------
    Write-Host ""
    Write-Host "Validating PHP..."

    if (-not (Test-Php -xamppDir $xamppDir)) {

        return [pscustomobject]@{
            ExitCode     = 2
            Message      = "PHP validation failed"
            XamppService = 3
        }
    }

    # -----------------------------------------------------
    # Launch Control Panel
    # -----------------------------------------------------
    # Write-Host ""
    # Write-Host "Launching XAMPP control panel..."

    # Start-Process `
    #    -FilePath "$xamppDir\xampp-control.exe" `
    #    -WindowStyle Minimized

    # -----------------------------------------------------
    # Success
    # -----------------------------------------------------
    return [pscustomobject]@{
        ExitCode     = 0
        Message      = "XAMPP started successfully"
        XamppService = 0
    }
}

# =========================================================
# MAIN
# =========================================================

# ---------------------------------------------------------
# Check if XAMPP already active
# exitCode = 0 xampp requested to run is active no need to start again
# exitCode = 1 start requested xampp, none are active  
# ---------------------------------------------------------
$exitCode = 0
. "$rootDir\etc\chkEnabled.ps1" -RequestedXamppDir $xamppDir

# write-host "variables set by chkEnabled in startxampp"
# write-host "exitCode: $exitcode"
# write-host "status: $Status"
# write-host "xamppDir: $xamppDir"
# write-host "xamppDirCur: $xamppDirCur"
# write-host "Htdocs: $Htdocs"
# write-host "XamppService: $XamppService" 



# if exitcode = 1, need to start requested xampp,either none 
#                  available or the active is not equal to requested
#               0, currently active is equal to requested

if ($exitCode -eq 1) {  
 
    # -----------------------------------------------------
    # Internal Installation Validation
    # -----------------------------------------------------

    if ($xamppInstall -ieq "internal") {

	& "$rootDir\etc\chkXinstall.ps1" $xamppDir
	$exitCode = $LASTEXITCODE


	if ($exitCode -eq 1) {
	    $inputMsg = "It appears the XAMPP installation has been moved to a new directory or drive.  Would you like to run <setup>? (Yes/No)"

	    $menuChoice = Show-Alert `
                -Message $inputMsg `
                -Buttons "YesNo"

	    if ($menuChoice -ieq "yes") {
		& "$rootDir\etc\setupXampp.ps1"
		if ($LASTEXITCODE -eq 1) {
		  exit 3
		}
            } else {
                exit 3
            } #  if ($menuChoice -ieq "yes")
        } # if ($exitCode -eq 1)
    } # if ($xamppInstall -ieq "internal")
    
    # -----------------------------------------------------
    # Start XAMPP
    # -----------------------------------------------------
    
    $exitCode = 0

    $result = Start-Xampp -xamppDir $xamppDir -xamppDirCur $xamppDirCur
    
    # $result.ExitCode = 0 - Successful operation
    # $result.ExitCode = 1 -  Errors while trying to stop current Xampp
    # $result.ExitCode = 2 - at least one service did not start
    # $result.ExitCode = 3 - control panel did not start, no services available

    if ($result.ExitCode -ne 0) {
	Show-Alert -Message $result.Message | Out-Null
	# Write-Output "$($result.ExitCode)|$($result.XamppService)|$($result.Message)"
	$exitCode = $result.ExitCode
    }

} # end if exitcode = 1 (start xampp)

# $exitode = 0 - xampp is active and equal to requested
exit $exitCode