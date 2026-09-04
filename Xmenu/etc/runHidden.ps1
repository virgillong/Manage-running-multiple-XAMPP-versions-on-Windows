param(
    [string]$MenuID
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Default path fallback for rootDir
if (-not $env:rootDir) {
    $env:rootDir = (Resolve-Path "$PSScriptRoot\..").Path
}
$rootDir = $env:rootDir 

$filePath = Join-Path $rootDir "data\buttons.txt"

$records = Get-Content $filePath | ForEach-Object {
    $f = $_ -split '\|'
    [PSCustomObject]@{
        Name = $f[0]
        ID   = $f[1]
        URL  = $f[2]
        Path = if ($f.Count -gt 3) { $f[3] } else { $null }
    }
}

$match = $records | Where-Object { $_.ID -eq $MenuID } | Select-Object -First 1

# $useProcess  = $match -and $match.Path
$useProcess  = $match
$processPath = $match.Path
$processURL = $match.URL


if ($processPath -like '*{DRIVE}*') {
    $processPath = $processPath -replace '\{DRIVE\}\\', ''
}

Import-Module (Join-Path $rootDir "etc\includes\UIHelpers.psm1") -Force
$themeFile = Join-Path $rootDir "data\theme.txt"
$currentMode = Import-ThemeState -themeFile $themeFile

[System.Windows.Forms.Application]::EnableVisualStyles()

# Add-Type @"
# using System;
# using System.Runtime.InteropServices;
# public class Win32 {
#     [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
#    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
# }
# "@

# $consolePtr = [Win32]::GetConsoleWindow()
# 0 = hide
# [Win32]::ShowWindow($consolePtr, 0)

$form = New-Object Windows.Forms.Form
$form.Text = "Processing..."
$form.Size = New-Object Drawing.Size(400,120)
$form.StartPosition = "CenterScreen"
Set-FormTheme -Form $form -Mode $currentMode

$label = New-Object Windows.Forms.Label
# $label.Text = "Starting task..."
$label.Text = "Starting: $processPath   Opening: $processURL"

$label.AutoSize = $true
$label.Location = New-Object Drawing.Point(20,20)
Set-LabelStyle -Label $label -Mode $currentMode

$progress = New-Object Windows.Forms.ProgressBar
$progress.Style = "Marquee"
$progress.Size = New-Object Drawing.Size(340,20)
$progress.MarqueeAnimationSpeed = 30   # <-- key line
$progress.Location = New-Object Drawing.Point(20,50)

$form.Controls.Add($label)
$form.Controls.Add($progress)

if ($useProcess) {
    # Attach event only when using process mode
    $form.Add_Shown({
        $process = Start-Process -FilePath "$rootDir\menu.bat" `
            -ArgumentList $MenuID `
            -WindowStyle Hidden `
            -PassThru

        while (-not $process.HasExited) {
            Start-Sleep -Milliseconds 200
            [System.Windows.Forms.Application]::DoEvents()
        }

        $label.Text = "Completed"
        $form.Close()
    })

    # Show the form
    [System.Windows.Forms.Application]::Run($form)
}
else {
    # No form at all — just run the batch directly
    & "$rootDir\menu.bat" $MenuID
}
