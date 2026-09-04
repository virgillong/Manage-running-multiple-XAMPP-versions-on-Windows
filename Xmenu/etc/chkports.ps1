# checkports.ps1

param(
    [string]$GetUserInput = "true"
)

# Default path fallback for rootDir
if (-not $env:rootDir) {
    $env:rootDir = (Resolve-Path "$PSScriptRoot\..").Path
}
$rootDir = $env:rootDir 

# ---------------------------------------------------------
# Imports
# ---------------------------------------------------------

Import-Module (Join-Path $env:rootDir "etc\includes\UIHelpers.psm1") -Force
Import-Module (Join-Path $env:rootDir "etc\includes\alert.psm1") -Force

$themeFile = Join-Path $env:rootDir "data\theme.txt"
$currentMode = Import-ThemeState -themeFile $themeFile


# Do not globally silence errors while debugging
$ErrorActionPreference = "Continue"
# $ErrorActionPreference = "SilentlyContinue"


# ---------------------------------------------------------
# Configuration
# ---------------------------------------------------------

$ports = @(80,3306)

# Only terminate known XAMPP processes
$allowedProcesses = @(
    "httpd",
    "mysqld"
)

# ---------------------------------------------------------
# Functions
# ---------------------------------------------------------

function Test-IsAdmin {

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()

    $principal = New-Object Security.Principal.WindowsPrincipal($identity)

    return $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

function Get-PortListeners {

    param(
        [int[]]$Ports
    )

    $results = @()

    foreach ($port in $Ports) {

        # Write-Host "Checking port $port..."

        $connections = Get-NetTCPConnection `
            -LocalPort $port `
            -State Listen `
            -ErrorAction SilentlyContinue

        foreach ($conn in $connections) {

            $processID = $conn.OwningProcess

            # Skip invalid/system PIDs
            if ($processID -eq 0 -or $processID -eq 4) {
                continue
            }

            $proc = Get-Process `
                -Id $processID `
                -ErrorAction SilentlyContinue

            if (-not $proc) {
                continue
            }

            # Skip current PowerShell process
            if ($processID -eq $PID) {
                Write-Host "Skipping current PowerShell PID $processID"
                continue
            }

            # ONLY allow known XAMPP processes
            if ($proc.ProcessName -notin $allowedProcesses) {

                Write-Host "Ignoring non-XAMPP process:"
                Write-Host "  PID:  $processID"
                Write-Host "  Name: $($proc.ProcessName)"

                continue
            }

            # Write-Host ""
            # Write-Host "Found matching listener:"
            # Write-Host "  Port: $port"
            # Write-Host "  PID : $processID"
            # Write-Host "  Name: $($proc.ProcessName)"

            # try {

             #   $path = $proc.Path

             #   if ($path) {
             #       Write-Host "  Path: $path"
             #   }
             # }
             # catch {
             # }

            $results += [PSCustomObject]@{
                Port        = $port
                PID         = $processID
                ProcessName = $proc.ProcessName
            }
        }
    }

    return $results |
        Sort-Object Port, PID -Unique
}

function Stop-PortProcesses {

    param(
        [array]$Processes
    )

    $accessDenied = $false

    foreach ($item in $Processes) {

        $processID = $item.PID
        $name      = $item.ProcessName
        $port      = $item.Port

        Write-Host ""
        Write-Host "Stopping PID $processID ($name) using port $port..."

        # Extra safety
        if ($processID -eq $PID) {

            Write-Host "Skipping current PowerShell process."
            continue
        }

        try {

            Stop-Process `
                -Id $processID `
                -Force `
                -ErrorAction Stop

            Start-Sleep -Seconds 2

            if (Get-Process -Id $processID -ErrorAction SilentlyContinue) {

                Write-Host "Failed to terminate PID $processID"
            }
            else {

                Write-Host "Successfully terminated PID $processID"
            }
        }
        catch {

            Write-Host ""
            Write-Host "ERROR stopping PID $processID"
            Write-Host $_

            if (
                $_.Exception.Message -match "Access is denied"
            ) {
                $accessDenied = $true
            }
        }
    }

    # ---------------------------------------------------------
    # Additional Apache cleanup
    # Apache may leave child httpd.exe processes running
    # even after the main PID using port 80 is terminated.
    # ---------------------------------------------------------

    $apacheProcesses = Get-Process `
        -Name "httpd" `
        -ErrorAction SilentlyContinue

    if ($apacheProcesses) {

        Write-Host ""
        Write-Host "Performing Apache cleanup..."

        foreach ($apacheProc in $apacheProcesses) {

            if ($apacheProc.Id -eq $PID) {
                continue
            }

            try {

                Write-Host "Stopping Apache PID $($apacheProc.Id)..."

                Stop-Process `
                    -Id $apacheProc.Id `
                    -Force `
                    -ErrorAction Stop
            }
            catch {

                Write-Host ""
                Write-Host "ERROR stopping Apache PID $($apacheProc.Id)"
                Write-Host $_

                if (
                    $_.Exception.Message -match "Access is denied"
                ) {
                    $accessDenied = $true
                }
            }
        }

        # Wait for Apache to fully terminate
        $maxWait = 10

        for ($i = 0; $i -lt $maxWait; $i++) {

            $remainingApache = Get-Process `
                -Name "httpd" `
                -ErrorAction SilentlyContinue

            if (-not $remainingApache) {

                break
            }

            Start-Sleep -Seconds 1
        }

        # Final verification
        $remainingApache = Get-Process `
            -Name "httpd" `
            -ErrorAction SilentlyContinue

        if ($remainingApache) {

            Write-Host ""
            Write-Host "WARNING: Apache still running"

            $remainingApache |
                Select-Object Id, ProcessName, Path |
                Format-Table -AutoSize
        }
        else {

            Write-Host ""
            Write-Host "Apache fully stopped"
        }
    }

    return $accessDenied
}

# ---------------------------------------------------------
# Start
# ---------------------------------------------------------

Write-Host ""
Write-Host "Checking Apache/MySQL ports..."
Write-Host ""

$listeners = Get-PortListeners -Ports $ports

# ---------------------------------------------------------
# No Conflicts Found
# ---------------------------------------------------------

if (-not $listeners) {

    Write-Host ""
    Write-Host "Success: No XAMPP processes found using required ports."
    Write-Host ""

    exit 0
}

# ---------------------------------------------------------
# Display Conflicts
# ---------------------------------------------------------

Write-Host ""
Write-Host "Detected XAMPP-related listeners:"
Write-Host ""

$listeners |
    Format-Table Port, PID, ProcessName -AutoSize

# ---------------------------------------------------------
# Ask User
# ---------------------------------------------------------

if ($GetUserInput -ieq "false") {

    $terminate = $true
}
else {

    $result = Show-Alert `
        -Message "Apache/MySQL processes are using required ports. Terminate them?" `
        -Buttons YesNo `
        -Title "Confirm Termination"

    $terminate = ($result -eq "Yes")
}

# ---------------------------------------------------------
# User Declined
# ---------------------------------------------------------

if (-not $terminate) {

    Write-Host ""
    Write-Host "Processes were not terminated."
    Write-Host ""

    exit 1
}

# ---------------------------------------------------------
# Attempt Termination
# ---------------------------------------------------------

Write-Host ""
Write-Host "Attempting to clear ports..."
Write-Host ""

$needsElevation = Stop-PortProcesses -Processes $listeners


# ---------------------------------------------------------
# Elevate If Needed
# ---------------------------------------------------------

if ($needsElevation -and -not (Test-IsAdmin)) {

    Write-Host ""
    Write-Host "Administrator privileges required."
    Write-Host "Restarting script as Administrator..."
    Write-Host ""

    Start-Process powershell `
        -Verb RunAs `
        -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# ---------------------------------------------------------
# Verification
# ---------------------------------------------------------

Start-Sleep -Seconds 2

$remaining = Get-PortListeners -Ports $ports

Write-Host ""

if ($remaining) {

    Write-Host "Failure: Some ports are still active."
    Write-Host ""

    $remaining |
        Format-Table Port, PID, ProcessName -AutoSize

    Write-Host ""
    exit 1
}

# ---------------------------------------------------------
# Success
# ---------------------------------------------------------

Write-Host "Success: Apache/MySQL ports cleared."
Write-Host ""
Write-Host "No blocking XAMPP processes remain."
Write-Host ""

exit 0