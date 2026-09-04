# chkXampp.ps1

param(
    [string]$RequestedXamppDir = ""
)


# Do not globally silence errors while debugging
$ErrorActionPreference = "Continue"

# ---------------------------------------------------------
# Root Directory
# ---------------------------------------------------------

if (-not $env:rootDir) {
    $env:rootDir = (Resolve-Path "$PSScriptRoot\..").Path
}
$rootDir = $env:rootDir

# ---------------------------------------------------------
# Defaults
# ---------------------------------------------------------

$exitCode = 0
$xamppDirCur = ""
$XamppService = 0

# ---------------------------------------------------------
# Call chkApache.ps1
# ---------------------------------------------------------

$apacheInfo = & "$rootDir\etc\chkApache.ps1"

foreach ($line in $apacheInfo) {

    if ($line -match "=") {

        $parts = $line -split "=", 2

        $name  = $parts[0].Trim()
        $value = $parts[1].Trim()

        Set-Variable -Name $name -Value $value
    }
}


# ---------------------------------------------------------
# Apache Running?
# ---------------------------------------------------------

if ($Status -ine "Running") {

    $exitCode = 1 # set to no xampp active
    $xamppDirCur = ""
    Write-Output "$exitCode|$Status|$Htdocs|$xamppDirCur|$XamppService"
    return
}

# ---------------------------------------------------------
# Determine Active XAMPP Directory
# ---------------------------------------------------------

$xamppDirCur = $ExePath -replace '\\apache\\bin\\httpd\.exe$', ''

# ---------------------------------------------------------
# Requested Version Validation
# ---------------------------------------------------------

if ($RequestedXamppDir -ne "") {

    $xamppDir = $RequestedXamppDir.Replace("/", "\")

    if ($xamppDirCur -ieq $xamppDir) {

        Write-Host "Requested: $xamppDir  Currently active: $xamppDirCur"
    }
    else {

        Write-Host "Apache server is running $xamppDirCur which is not the correct version"
        $exitCode = 1
	Write-Output "$exitCode|$Status|$Htdocs|$xamppDirCur|$XamppService"
        return
    }
}
# There is an active xampp
#    no requested xampp parameter or
#    requested parameter was provided and its equal to current running
#     
# ---------------------------------------------------------
# Service Availability
#
# 0 = apache + mysql available
# 1 = apache unavailable
# 2 = mysql unavailable
# 3 = neither available
# ---------------------------------------------------------

$XamppService = 0

# ---------------------------------------------------------
# Check Apache Port 80
# ---------------------------------------------------------

$apachePort = Get-NetTCPConnection `
    -LocalPort 80 `
    -State Listen `
    -ErrorAction SilentlyContinue

if (-not $apachePort) {

    $XamppService += 1
    $exitCode = 1
}

# ---------------------------------------------------------
# Check MySQL Port 3306
# ---------------------------------------------------------

$mysqlPort = Get-NetTCPConnection `
    -LocalPort 3306 `
    -State Listen `
    -ErrorAction SilentlyContinue

if (-not $mysqlPort) {

    $XamppService += 2
    $exitCode = 1
}

# ---------------------------------------------------------
# Exit
# ---------------------------------------------------------
Write-Output "$exitCode|$Status|$Htdocs|$xamppDirCur|$XamppService"

return