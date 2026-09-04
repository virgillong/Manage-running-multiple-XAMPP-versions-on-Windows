param(
    [string]$rootDir
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
if (-not $rootDir.EndsWith('\')) {
    $rootDir += '\'
}

function Get-VCRedistsToInstall {
    param ($Items)

    $result = @()

    foreach ($i in $Items) {

        if (-not [Environment]::Is64BitOperatingSystem -and $i.Arch -eq "x64") {
            continue
        }

        if (-not (Test-VCRedist -Family $i.Family -Arch $i.Arch)) {
            $result += $i
        }
        else {
            Write-Host "$($i.Name) is installed"
        }
    }

    return $result
}




# ----------------------------------------------------
# VC++ Family	Architecture	Detection method
# 2012		x86		DLL check		
# 2012		x64		DLL check		
# 2015–2022	x86/x64		Registry key		
# ----------------------------------------------------

function Test-VCRedist {
    param (
        [ValidateSet("2012","2015+")]
        [string]$Family,

        [ValidateSet("x86","x64")]
        [string]$Arch
    )

    $is64OS = [Environment]::Is64BitOperatingSystem

    if (-not $is64OS -and $Arch -eq "x64") {
        return $false
    }

    # ---- VC++ 2012: DLL-based detection (registry not reliable) ----
    if ($Family -eq "2012") {

        $dll = "msvcr110.dll"

        if ($is64OS) {
            if ($Arch -eq "x64") {
                $dllPath = if ([IntPtr]::Size -eq 4) {
                    "$env:SystemRoot\Sysnative\$dll"
                } else {
                    "$env:SystemRoot\System32\$dll"
                }
            }
            else {
                $dllPath = "$env:SystemRoot\SysWOW64\$dll"
            }
        }
        else {
            $dllPath = "$env:SystemRoot\System32\$dll"
        }

        return (Test-Path $dllPath)
    }

    # ---- VC++ 2015–2022: Registry-based detection ----
    if ($Family -eq "2015+") {

        $view = if ($Arch -eq "x64") {
            [Microsoft.Win32.RegistryView]::Registry64
        } else {
            [Microsoft.Win32.RegistryView]::Registry32
        }

        try {
            $baseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey(
                [Microsoft.Win32.RegistryHive]::LocalMachine,
                $view
            )

            $subKey = "SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\$Arch"
            $key = $baseKey.OpenSubKey($subKey)

            return ($key -and $key.GetValue("Installed", 0) -eq 1)
        }
        catch {
            return $false
        }
    }

    return $false
}

# ----------------------------------------------------
# Installer (Local exe file to install → Web fallback)
# ----------------------------------------------------

function Install-VCRedist {
    param (
        [string]$LocalExe,
        [string]$DownloadUrl
    )

    if (Test-Path $LocalExe) {
        $exe = $LocalExe
    }
    else {
        $exe = "$env:TEMP\" + [IO.Path]::GetFileName($DownloadUrl)
        Invoke-WebRequest $DownloadUrl -OutFile $exe -UseBasicParsing
    }

    Start-Process $exe -ArgumentList "/install /quiet /norestart" -Wait -NoNewWindow
}


Import-Module (Join-Path $rootDir "etc\includes\UIHelpers.psm1") -Force
Import-Module (Join-Path $rootDir "etc\includes\alert.psm1") -Force
$themeFile = Join-Path $rootDir "data\theme.txt"
$currentMode = Import-ThemeState -themeFile $themeFile

$items = @(
    @{ Name="VC++ 2012 x86"; Family="2012";  Arch="x86"; File="vc2012_x86.exe"; Url="https://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/vcredist_x86.exe" },
    @{ Name="VC++ 2012 x64"; Family="2012";  Arch="x64"; File="vc2012_x64.exe"; Url="https://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/vcredist_x64.exe" }
    # @{ Name="VC++ 2015-2022 x86"; Family="2015+"; Arch="x86"; File="vc2015_x86.exe"; Url="https://aka.ms/vs/17/release/vc_redist.x86.exe" },
    # @{ Name="VC++ 2015-2022 x64"; Family="2015+"; Arch="x64"; File="vc2015_x64.exe"; Url="https://aka.ms/vs/17/release/vc_redist.x64.exe" }
)

$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {

    $itemsToInstall = Get-VCRedistsToInstall $items

    if ($itemsToInstall.Count -eq 0) {
        exit
    }

    Start-Process powershell.exe `
        -Verb RunAs `
        -ArgumentList @(
            '-ExecutionPolicy', 'Bypass'
            '-File', $PSCommandPath
            '-rootDir', $rootDir
        )
    exit
}


$itemsToInstall = Get-VCRedistsToInstall $items

$redist = Join-Path $rootDir "data\redist"

foreach ($i in $itemsToInstall) {
    Write-Host "Installing $($i.Name)"
    Install-VCRedist `
        -LocalExe (Join-Path $redist $i.File) `
        -DownloadUrl $i.Url
}

pause


