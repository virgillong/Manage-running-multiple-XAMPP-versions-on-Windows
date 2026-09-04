Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing


# Default path fallback for rootDir
if (-not $env:rootDir) {
    $env:rootDir = (Resolve-Path "$PSScriptRoot\..").Path
}
$rootDir = $env:rootDir 

if (-not $env:curDrv) {
    $env:curDrv = (Resolve-Path "$PSScriptRoot\..\..").Path
}
$curDrv = $env:curDrv

Import-Module (Join-Path $rootDir "etc\includes\UIHelpers.psm1") -Force
Import-Module (Join-Path $rootDir "etc\includes\addinputrow.psm1") -Force
Import-Module (Join-Path $rootDir "etc\includes\alert.psm1") -Force

$themeFile = Join-Path $rootDir "data\theme.txt"
$currentMode = Import-ThemeState -themeFile $themeFile

# Load file
$filePath = Join-Path $rootDir "data\buttons.txt"
$entries = @()

# $fields[3] is the path to xampp folder, the drive may be
# literal a-z or portable {DRIVE}, the latter needs to be
# converted to the current drive

if (Test-Path $filePath) {
    $entries = Get-Content $filePath | ForEach-Object {
        $fields = $_ -split '\|'
        if ($fields.Count -ge 4) {
            if ($fields[3] -match '^[A-Za-z]:\\') {
                # literal path, no replacement
                $expanded = $fields[3]
            } else {
                $expanded = $fields[3] -replace '{DRIVE}', $curDrv
            }
	    # Validate it's a real directory
            if (Test-Path $expanded -PathType Container) {

                # Normalize via OS (removes weird syntax issues)
                $resolved = Resolve-Path $expanded -ErrorAction SilentlyContinue

                if ($resolved) {
                    $resolved.Path # this sends it to $entries
                }
            }
        }
    } | Sort-Object -Unique
}
    

# Create the form
$form = New-Object System.Windows.Forms.Form
$form.Font = $global:FontRegular
$form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Font
$form.Text = "Update Xampp Config File Paths" 
$form.Size = New-Object System.Drawing.Size($global:formWidth, 200)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = 'Sizable'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.KeyPreview = $true   # Allows Enter/Esc handling
Set-FormTheme -Form $form -Mode $currentMode

$global:inputLeft +=30

$topStrt = 40
$spacing = 40

$comboBox,$label = Add-InputRow $form "New XAMPP Folder Path:"  $topStrt  "combobox"
$label.AutoSize = $false
$label.Width = 150
$label.Height = 60
$comboBox.Items.AddRange($entries)
$comboBox.SelectedIndex = 0

$top = (1*$spacing) + $topstrt

$ForceCheckbox, $label = Add-InputRow $form "" $top "checkbox"
$ForceCheckbox.Text = "Override system path indicating old Xampp location"

$top = (2*$spacing) + $topstrt

$oldXTextbox, $oldXLabel = Add-InputRow $form "Old Xampp path" $top "textbox"
$oldXLabel.AutoSize = $false
$oldXLabel.Width = 150
$oldXLabel.Height = 60

$global:browseLeft +=30
$oldXbrowseBtn, $Label = Add-InputRow $form "" $top "browse"
$oldXbrowseBtn.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    # $dlg.SelectedPath = $rootDir
    # $dlg.SelectedPath = [Environment]::GetFolderPath("MyDocuments")
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
	    $oldXTextbox.Text = $dlg.SelectedPath
    }
}.GetNewClosure())



# OK Button
$okButton = New-Object System.Windows.Forms.Button
$okButton.Text = "OK"
$okButton.Location = New-Object System.Drawing.Point(250,$top)
Set-ButtonStyle -Button $okButton -Mode $currentMode
$form.Controls.Add($okButton)


# Cancel Button
$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Text = "Cancel"
Set-ButtonStyle -Button $cancelButton -Mode $currentMode
$cancelButton.Location = New-Object System.Drawing.Point(340,$top)
$form.Controls.Add($cancelButton)

$global:selectedItem = $null
$okButton.Add_Click({
   $form.Tag = "OK"
    $hasXfolder = $ForceCheckbox.Checked -and $oldXTextbox.Text.Trim() -ne ""
    if ($ForceCheckbox.Checked -and -not $hasXfolder) {
	Show-Alert -Message "You must enter a valid Xampp folder."   
    } else {
	$form.Tag = "OK"
	$form.Close()
    }
})

$cancelButton.Add_Click({ 
     $form.Tag = "cancel"
    $form.Close() 
})

# hide by default
$oldXTextbox.Visible = $false
$oldXLabel.Visible = $false
$oldXbrowseBtn.Visible = $false
$ForceCheckbox.Add_CheckedChanged({
    $isVisible = $ForceCheckbox.Checked
    $oldXTextbox.Visible = $isVisible
    $oldXLabel.Visible = $isVisible
    $oldXbrowseBtn.Visible = $isVisible
    if ($isVisible) {
	$top = (3*$spacing) + $topstrt
	$okButton.Location = New-Object System.Drawing.Point(250, $top)
	$cancelButton.Location = New-Object System.Drawing.Point(340, $top)
	$form.Size = New-Object System.Drawing.Size($global:formWidth, 240)
    } else {
	$top = (2*$spacing) + $topstrt
	$okButton.Location = New-Object System.Drawing.Point(250, $top)
	$cancelButton.Location = New-Object System.Drawing.Point(340, $top)
	$form.Size = New-Object System.Drawing.Size($global:formWidth, 200)
    }
})


# --- Keyboard shortcuts ---
$form.Add_KeyDown({
    param($sender, $e)
    switch ($e.KeyCode) {
        'Enter'  { $okButton.PerformClick(); $e.Handled = $true }
        'Escape' { $cancelButton.PerformClick(); $e.Handled = $true }
    }
})


# Show form
$form.Topmost = $true
$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()

# ❗ OUTPUT HAPPENS HERE, after the dialog has closed


# =========================================================
# XAMPP Path Configuration Update
# =========================================================

if ($form.Tag -eq "OK") {

    # Path to new XAMPP directory
    $XamppDirNew = $comboBox.SelectedItem

    # Force setup option
    $forceSetup = $ForceCheckbox.Checked

    # Current XAMPP directory path
    # Used to replace existing paths in config files
    if ($ForceCheckbox.Checked) {
        $XamppDirCurrent = $oldXTextbox.Text
    }

}
else {

    Write-Output "cancel"
    exit 1
}

# =========================================================
# Get current install directory from install.sys
# =========================================================

$file = Join-Path $XamppDirNew "install\install.sys"

$installDir = ""

if (!(Test-Path $file)) {

    Write-Host "File $file not found! May be new installation"
}
else {

    Get-Content $file | ForEach-Object {

        $line = $_

        Write-Host $line

        if ($line -match '^DIR =') {

            $installDir = ($line -split '=', 2)[1].Trim()
        }
    }
}

# =========================================================
# Display update information
# =========================================================

Write-Host ""

if (-not $forceSetup) {

    Write-Host "File paths within XAMPP configuration files will be updated ..."
    Write-Host "        $installDir will be changed to $XamppDirNew"
    Write-Host ""
}
else {

    Write-Host "File paths within XAMPP configuration files will be updated ..."
    Write-Host "    $XamppDirCurrent will be changed to $XamppDirNew"
    Write-Host ""
}

# =========================================================
# Test PHP executable
# =========================================================

$PHP_BIN   = Join-Path $XamppDirNew "php\php.exe"
$CONFIG_PHP = Join-Path $rootDir "Utilities\install.php"

Write-Host ""
Write-Host "[XAMPP]: Test php.exe with php\php.exe -n -d output_buffering=0 --version ..."

& $PHP_BIN -n -d output_buffering=0 --version

if ($LASTEXITCODE -gt 0) {

    $exitCode = 1

    Write-Host "[ERROR]: Test php.exe failed !!!"

    $message = "Request Terminated"

    return
}

Write-Host "[XAMPP]: Test for the php.exe successfully passed. Good!"
Write-Host ""

# =========================================================
# Run install.php
# =========================================================

& $PHP_BIN -n -d output_buffering=0 `
    $CONFIG_PHP `
    $XamppDirNew `
    $forceSetup `
    $XamppDirCurrent

# =========================================================
# Exit Codes
# =========================================================
# 0 = config files and install.sys updated
# 1 = nothing to do
# 2 = no matches found, install.sys not updated
# 3 = no matches found using force setup path
# =========================================================

$exitCode = $LASTEXITCODE

switch ($exitCode) {

    0 {
        Write-Host "config files updated successfully to $XamppDirNew"
        $inputMsg = "config files updated successfully to $XamppDirNew"
	$exitCode = 0
    }

    1 {
        Write-Host "nothing to do"
        $inputMsg = "nothing to do"
	$exitCode = 0
    }

    2 {
	Write-Host "No matches found, install.sys not updated, may indicate issue with install.sys"
        $inputMsg = "No matches found, install.sys not updated, may indicate issue with install.sys"
	$exitCode = 1
    }

    3 {
        Write-Host "No matches found using alternative path defined by force setup"
        $inputMsg = "No matches found using alternative path defined by force setup"
	$exitCode = 1
    }

    default {
        $inputMsg = "Unknown result"
	$exitCode = 1
    }
}

# =========================================================
# Show Message
# =========================================================

Show-Alert -Message  $inputMsg | Out-Null

exit $exitCode