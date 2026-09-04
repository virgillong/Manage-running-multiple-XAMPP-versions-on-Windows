# chkInstall.ps1

param(
    [string]$xPath
)


# if ($PSBoundParameters.ContainsKey('xPath')) {
#    Write-Host "xPath was provided"
# }

# Normalize path
$xPath = [System.IO.Path]::GetFullPath($xPath).TrimEnd('\')

if (-not $env:curDrv) {
    $env:curDrv = (Resolve-Path "$PSScriptRoot\..\..").Path
}
$curDrv = $env:curDrv 

$curDrvLtr = (Get-Item $curDrv).PSDrive.Name + ":"

$exitCode = 0
$message  = ""

# Build install.sys path
$INSTALL_SYS = Join-Path $xPath "install\install.sys"

# Check existence
if (-not (Test-Path $INSTALL_SYS)) {
    $exitCode = 1
    $message = "could not access xampp configuration file $INSTALL_SYS, please check your installation"
    
    Write-Host $message
    exit $exitCode
}

# ===== READ DIR FROM install.sys =====
$INSTALLED_DIR = $null

Get-Content $INSTALL_SYS | ForEach-Object {

    if ($_ -match '^\s*DIR\s*=(.*)$') {
        $INSTALLED_DIR = $matches[1].Trim().Trim('"')
    }
}

if (-not $INSTALLED_DIR) {
    $exitCode = 1
    $message = "ERROR: in chkInstall.ps1 ... DIR entry not found in install.sys"

    Write-Host $message
    exit $exitCode
}

# Normalize slashes
$INSTALLED_DIR = $INSTALLED_DIR -replace '/', '\'

# ===== RESOLVE RELATIVE PATHS =====
#
# If install.sys DIR starts with "\" → relative path
# Convert \xampp8 → C:\xampp8
#

if ($INSTALLED_DIR.StartsWith("\")) {
    $RESOLVED_DIR = "$curDrvLtr$INSTALLED_DIR"
}
else {
    $RESOLVED_DIR = $INSTALLED_DIR
}

# Normalize resolved path
$RESOLVED_DIR = [System.IO.Path]::GetFullPath($RESOLVED_DIR).TrimEnd('\')

# ===== COMPARE NORMALIZED ABSOLUTE PATHS =====

if ($RESOLVED_DIR.ToLower() -eq $xPath.ToLower()) {

    $exitCode = 0

    # Optional debug message
    Write-Host "xampp installation '$xPath' is equal to config settings '$INSTALLED_DIR'"

} else {

    $exitCode = 1
    Write-Host "     The XAMPP configuration current path: $RESOLVED_DIR"
    Write-Host "     Does not match new path $xPath."
}

exit $exitCode