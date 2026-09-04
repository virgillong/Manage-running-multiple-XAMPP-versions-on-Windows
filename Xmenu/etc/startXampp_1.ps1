# loadXampp.ps1

param(
    [string]$xamppDir
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
# Helper: Wait For Port
# ---------------------------------------------------------

function Wait-ForPort {

    param(
        [int]$Port,
        [int]$Retries = 10,
        [int]$DelaySeconds = 2
    )

    for ($i = 1; $i -le $Retries; $i++) {

	Write-Host "Attempt $i : Waiting for port $Port to open..."
        Start-Sleep -Seconds $DelaySeconds

        $portFound = Get-NetTCPConnection `
            -LocalPort $Port `
            -State Listen `
            -ErrorAction SilentlyContinue

        if ($portFound) {

            Write-Host "Port $Port is open! Proceeding..."
            return $true
        }

        
    }

    return $false
}

# ---------------------------------------------------------
# Function: Start-Xampp
# ---------------------------------------------------------

function Start-Xampp {

    param(
        [string]$xamppDir,
	[string]$xamppDirCur
    )

    $exitCode = 0
    $XamppService = 0

    # -----------------------------------------------------
    # Verify XAMPP Directory
    # -----------------------------------------------------

    if (-not (Test-Path $xamppDir)) {
	 $exitCode = 1
        $message = "Cannot find $xamppDir check your configuration"
        return [pscustomobject]@{
	    ExitCode     = $exitCode
	    Message      = $message
	    XamppService = $xamppService
	}
    }

    # -----------------------------------------------------
    # Configure Auto Start
    # -----------------------------------------------------

    & "$rootDir\etc\autostrt.ps1" -xamppDir $xamppDir

    if ($LASTEXITCODE -ne 0) {

        $exitCode = 1
        $message =
            "Issue setting auto start parameters in the new Xampp"
         return [pscustomobject]@{
	    ExitCode     = $exitCode
	    Message      = $message
	    XamppService = $xamppService
	}
    }

    # -----------------------------------------------------
    # Stop Existing XAMPP
    # -----------------------------------------------------

    & "$rootDir\etc\stopXampp.ps1" -xamppDir $xamppDirCur
    
     if ($LASTEXITCODE -ge 1) {
	if ($LASTEXITCODE -eq 1) {
	    $message = "Issue terminating Control Panel"
	}
	if ($LASTEXITCODE -eq 2) {
	    $message = "Issue terminating ports needed by Xampp"
	}
	
	$exitCode = 1
	
        return [pscustomobject]@{
	    ExitCode     = $exitCode
	    Message      = $message
	    XamppService = $xamppService
	}
     }

    

    Write-Host ""
    Write-Host "Starting XAMPP Control Panel using $xamppDir"

    # -----------------------------------------------------
    # Start XAMPP Control Panel
    # ----------------------------------------------------

    Start-Process `
	-FilePath "$xamppDir\xampp-control.exe" `
	-WindowStyle Minimized


    # -----------------------------------------------------
    # Wait For XAMPP Control Panel
    # -----------------------------------------------------

    $started = $false

    for ($i = 1; $i -le 5; $i++) {

        Start-Sleep -Seconds 5

        $proc = Get-Process `
            -Name "xampp-control" `
            -ErrorAction SilentlyContinue

        if ($proc) {

            $started = $true
            break
        }

        Write-Host "Attempt $i : Waiting for XAMPP control panel to start..."
    }

    if (-not $started) {

        Write-Host ""
        Write-Host "Failure: XAMPP control panel did not start after 5 attempts"
        $exitCode = 3
        $XamppService = 3
        $message = "Failure: Could not start Xampp Control Panel"
         return [pscustomobject]@{
	    ExitCode     = $exitCode
	    Message      = $message
	    XamppService = $xamppService
	}
    }

    Write-Host ""
    Write-Host "XAMPP control panel started"

    # -----------------------------------------------------
    # Wait For Apache Port
    # -----------------------------------------------------

    if (-not (Wait-ForPort -Port 80)) {

        $exitCode = 2
        $XamppService = 1
        $message = "Port 80 needed by webserver did not start"

         return [pscustomobject]@{
	    ExitCode     = $exitCode
	    Message      = $message
	    XamppService = $xamppService
	}
    }

    # -----------------------------------------------------
    # Wait For MySQL Port
    # -----------------------------------------------------

    if (-not (Wait-ForPort -Port 3306)) {

        $exitCode = 2
        $XamppService = 2
        $message =
            "Port 3306 needed by mysql database did not start"

         return [pscustomobject]@{
	    ExitCode     = $exitCode
	    Message      = $message
	    XamppService = $xamppService
	}
    }

    return [pscustomobject]@{
	    ExitCode     = $exitCode
	    Message      = $message
	    XamppService = $xamppService
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


   # if ($xamppInstall -ieq "internal") {

    #    & "$rootDir\etc\chkXinstall.bat" $xamppDir



     #   if ($exitCode -eq 1) {

     #       $inputMsg =
     #           "$message Would you like to run <setup>? (Yes/No)"

      #      $menuChoice = Show-Alert `
      #          -Message $inputMsg `
      #          -Buttons "YesNo"

      #      if ($menuChoice -ieq "yes") {

      #          & "$rootDir\etc\setupXampp.ps1" $xamppDir

      #          switch ($exitCode) {

      #              0 {

      #                  Show-Alert `
      #                      -Message "Success: Setup completed successfully"
      #              }

       #             default {

       #                 Show-Alert `
       #                     -Message "Error: Setup did not update paths, issue with Xampp installation"

       #                 $XamppService = 3

       #                 goto END
       #             }
       #         }
       #     }
       #     else {

       #         $XamppService = 3

       #         goto END
       #     }
       # }
    # }

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