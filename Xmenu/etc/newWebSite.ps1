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
Import-Module (Join-Path $rootDir "etc\includes\compareArchive.psm1") -Force



$themeFile = Join-Path $rootDir "data\theme.txt"
$currentMode = Import-ThemeState -themeFile $themeFile


$global:inputLeft += 25
$global:inputWidth -= 25
$global:inputWidth += 100
$global:browseLeft += 100
$global:formWidth  += 100

# Create the form
$form = New-Object System.Windows.Forms.Form
$form.Font = $global:FontRegular
$form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Font
$form.Text = "Create new website" 
$form.Size = New-Object System.Drawing.Size($global:formWidth, 446)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = 'Sizable'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.KeyPreview = $true   # Allows Enter/Esc handling
Set-FormTheme -Form $form -Mode $currentMode

# --------------------------------------------
# Request Xampp Folder
# --------------------------------------------

$xamppFolder,$label = Add-InputRow $form "XAMPP Folder:"   40  "textbox"

$browseXfolder, $Label = Add-InputRow $form "" 40 "browse"
$browseXfolder.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.SelectedPath = $rootDir
    # $dlg.SelectedPath = [Environment]::GetFolderPath("MyDocuments")
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
	$xamppFolder.Text = $dlg.SelectedPath
    }	
}.GetNewClosure())

# --------------------------------------------
# Request Website Folder
# --------------------------------------------
$wsFolder,$label = Add-InputRow $form "Website" 80 "textbox"
$wslabel = New-Object System.Windows.Forms.Label
$wslabel.Text = "\\localhost\"
Set-LabelStyle -Label $wslabel -Mode $currentMode
$wslabel.ForeColor = "gray"
$wslabel.Location = New-Object System.Drawing.Point(85, 85)
$label.AutoSize = $true
$form.Controls.Add($wslabel)


# --------------------------------------------
# Request Database Name
# --------------------------------------------
$dbName,$label = Add-InputRow $form "Database Name" 120 "textbox"


# ------------------------------------------------------------------
# Checkbox: copy a backup version of files to htdocs folder
# ------------------------------------------------------------------
$addWebFiles, $label = Add-InputRow $form "" 160 "checkbox"
$addWebFiles.Text = "Add Website Files and run setup"
$addWebFiles.Checked = $true
# --------------------------------------------
# Request Backup Files to be copied 
# --------------------------------------------
$backupFiles,$backupFileslabel = Add-InputRow $form "Backup Files:"   190   "listbox"
$backupFiles.HorizontalScrollbar = $true
# $backupFiles.ScrollAlwaysVisible = $true

$browseButton,$label = Add-InputRow $form "" 190  "browse"

$browseButton.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Multiselect = $true
    $dlg.Filter = "All files (*.*)|*.*"
    $dlg.InitialDirectory = '\\hpdesktop\sandbox\Postalsupply\BACKUPS'
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $count = $dlg.FileNames.Count

        if ($count -ne 2) {
            Show-Alert -Message "Please select exactly 2 files. You selected $count."
        }
        else {
            # Get files and remove empty lines
            $files = @($dlg.FileNames | Where-Object { $_.Trim() -ne "" })

            # Call Compare-ArchiveFiles with the selected files
            $result, $msg = Compare-ArchiveFiles -files $files

            if ($result) {
                $backupFiles.Items.Clear()
                $backupFiles.Items.AddRange($dlg.FileNames)
            }
            else {
                Show-Alert -Message $msg
                return
            }
        }
    }
}.GetNewClosure())


# --------------------------------------------
# OK Button
# --------------------------------------------
# OK Button
$okButton = New-Object System.Windows.Forms.Button
$okButton.Text = "OK"
$okButton.Location = New-Object System.Drawing.Point(250,300)
Set-ButtonStyle -Button $okButton -Mode $currentMode
$form.Controls.Add($okButton)

$okButton.Add_Click({

    $hasxFolder = $xamppFolder.Text.Trim() -ne ""
    $haswsFolder = $wsFolder.Text.Trim() -ne ""
    $hasdbName = $dbName.Text.Trim() -ne ""

    if (-not $hasxFolder) {
        Show-Alert -Message "Enter Xampp Folder"
        return
    }

    if (-not $haswsFolder) {
        Show-Alert -Message "Enter Website Folder"
        return
    }

    if (-not $hasdbName) {
        Show-Alert -Message "Enter Database Name"
        return
    }
    
    $installer = ""
    $archive = ""
    if ($addWebFiles.Checked) {
	# Get files and remove empty lines
	# $files = @($backupFiles.Items | Where-Object { $_.Trim() -ne "" })
	$files = @($backupFiles.Items | ForEach-Object { $_.ToString() } | Where-Object { $_.Trim() -ne "" })
	
	# Identify the installer.php file and the archive file (either .daf or .zip)
	$installer = $files | Where-Object { [System.IO.Path]::GetFileName($_) -ieq "installer.php" }
	$archive   = $files | Where-Object { $_ -match '\.(daf|zip)$' }
    }

    if ($addWebFiles.Checked) {
	 if (-not $installer -or -not $archive) {
	    Show-Alert -Message "You must select installer.php and a .daf or .zip archive."
	    return
	}
    }
   


    $form.Tag = @{
	xamppFolder = $xamppFolder.Text
	WebsiteFolder = $wsFolder.Text
	dbName = $dbName.Text 
        Installer = $installer
        Archive = $archive
    }

    $form.Close()
})

# Cancel Button
$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Text = "Cancel"
Set-ButtonStyle -Button $cancelButton -Mode $currentMode
$cancelButton.Location = New-Object System.Drawing.Point(340,300)
$form.Controls.Add($cancelButton)


$cancelButton.Add_Click({ 
    $form.Tag = ""
    $form.Close() 
})

# --- Keyboard shortcuts ---
$form.Add_KeyDown({
    param($sender, $e)
    switch ($e.KeyCode) {
        'Enter'  { $okButton.PerformClick(); $e.Handled = $true }
        'Escape' { $cancelButton.PerformClick(); $e.Handled = $true }
    }
})

# --------------------------------------------
# Hide by default backup folder and display
# when checkbox is checked
# --------------------------------------------
# Hide backup folder controls by default
# $backupFiles.Visible      = $false
# $backupFileslabel.Visible = $false
# $browseButton.Visible = $false

$addWebFiles.Add_CheckedChanged({
    $isVisible = $addWebFiles.Checked
    $backupFiles.Visible      = $isVisible
    $backupFileslabel.Visible = $isVisible
    $browseButton.Visible = $isVisible

    if ($isVisible) {
	$okButton.Location = New-Object System.Drawing.Point(250, 300)
	$cancelButton.Location = New-Object System.Drawing.Point(340, 300)
	$form.Size = New-Object System.Drawing.Size($global:formWidth, 446)
    } else {
	$okButton.Location = New-Object System.Drawing.Point(250, 230)
	$cancelButton.Location = New-Object System.Drawing.Point(340, 230)
	$form.Size = New-Object System.Drawing.Size($global:formWidth, 376)
    }
})


# Show form
$form.Topmost = $true
$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()

# ❗ OUTPUT HAPPENS HERE, after the dialog has closed

if (-not $form.Tag) {
    Write-Output "cancel"
    exit
}


if ($form.Tag) {

    $xamppFolder = $form.Tag.xamppFolder      # Xampp Folder
    $wsFolder    = $form.Tag.WebsiteFolder    # Website Folder
    $dbName      = $form.Tag.dbName           # Database Name

    if ($addWebFiles.Checked) {
        $installBkup = $true
        $Installer   = $form.Tag.Installer    # installer.php
        $Archive     = $form.Tag.Archive      # archive .daf or .zip
    }
    else {
        $installBkup = $false
    }

    # =========================================================
    # Initialize XAMPP
    # =========================================================

    $xamppdir     = $xamppFolder
    $xamppInstall = "internal"

    & "$rootDir\etc\startXampp.ps1" -xamppDir "$xamppDir" -xamppInstall "$xamppInstall"

    if ($exitCode -eq 1) {
        powershell -ExecutionPolicy Bypass `
            -File "$rootDir\etc\alert.ps1" `
            -Message "$message"

        return
    }

    $xamppDirCur = $xamppdir

    # =========================================================
    # Get Apache info
    # =========================================================

    $apacheInfo = & powershell -NoProfile -ExecutionPolicy Bypass `
        -File "$rootDir\etc\chkApache.ps1"

    foreach ($line in $apacheInfo) {
        if ($line -match '^(.*?)=(.*)$') {
            Set-Variable -Name $matches[1] -Value $matches[2]
        }
    }

    Write-Host "----------------------------------------"
    Write-Host "Apache Status : $Status"
    Write-Host "Apache Exe    : $ExePath"
    Write-Host "Apache htdocs : $Htdocs"
    Write-Host "----------------------------------------"

    # =========================================================
    # Create Website Folder
    # =========================================================

    $filepath = Join-Path $Htdocs $wsFolder

    Write-Host ""
    Write-Host "INFO: Creating new website: $filepath"

    # flag to indicate if website folder contents should be deleted
    $delContent = $true

    if (!(Test-Path $filepath)) {

        $inputMsg = "$filepath does not exist. Create?"

        $menuChoice = & powershell -ExecutionPolicy Bypass `
            -File "$rootDir\etc\alert.ps1" `
            -Message $inputMsg `
            -Title "Confirmation" `
            -Buttons YesNo

        if ($menuChoice -eq "yes") {

            Write-Host "$filepath does not exist. Creating..."

            New-Item -ItemType Directory -Path $filepath -Force | Out-Null

            $delContent = $false
        }
        else {
            $exitCode = 1
            $message  = "website folder required"
            return
        }
    }

    # =========================================================
    # Create Database
    # =========================================================

    $mysqlPath = Join-Path $xamppdir "mysql\bin\mysql.exe"

    # Trim spaces
    $dbName = $dbName.Trim()

    & $mysqlPath -u root -e "CREATE DATABASE IF NOT EXISTS $dbName;"

    if ($LASTEXITCODE -eq 0) {

        Write-Host ""
        Write-Host "INFO: Database: $dbName will be used for new installation"
    }
    else {

        Write-Host "ERROR: Failed to create database $dbName"

        $exitCode = 1
        return
    }

    # =========================================================
    # Check if backup files should be installed
    # =========================================================

    if (-not $installBkup) {
        return
    }

    # Check installer file
    if (!(Test-Path $Installer)) {

        Write-Host ""
        Write-Host "ERROR: Backup File: $Installer does NOT exist"

        $exitCode = 1
        return
    }

    # Check archive file
    if (!(Test-Path $Archive)) {

        Write-Host ""
        Write-Host "ERROR: Backup File: $Archive does NOT exist"

        $exitCode = 1
        return
    }

    # =========================================================
    # Delete Existing Content
    # =========================================================

    if ($delContent) {

        $inputMsg = "Warning all $filepath files and folders will be deleted and the database $dbName cleared ... are you sure? (Yes/No)"

        $menuChoice = & powershell -ExecutionPolicy Bypass `
            -File "$rootDir\etc\alert.ps1" `
            -Message $inputMsg `
            -Title "Confirmation" `
            -Buttons YesNo `
            -Batch

        if ($menuChoice -eq "yes") {

            Get-ChildItem -Path $filepath -Force |
                Remove-Item -Recurse -Force
        }
        else {

            $exitCode = 1
            return
        }
    }

    # =========================================================
    # Copy Files
    # =========================================================

    Write-Host "Copying files to $filepath"

    Copy-Item $Installer -Destination $filepath -Force
    Copy-Item $Archive   -Destination $filepath -Force

    # =========================================================
    # Start Website
    # =========================================================

    $website = "localhost/$wsFolder/installer.php"

    Write-Host ""
    Write-Host "Browser starting .... $website"
    Write-Host ""

    if ($website -notmatch '^https?://') {
        $website = "http://$website"
    }

    Start-Process $website

    $message = "SUCCESS: The default web browser will open a new window ... $website"
    $inputMsg = $message

    & powershell.exe -ExecutionPolicy Bypass `
        -File (Join-Path $rootDir "etc\alert.ps1") `
        -Message $inputMsg
}
else {

    Write-Output "cancel"
    exit 1
}