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

# capture environmental variables
$Htdocs = $env:Htdocs 
$xamppDirCur = $env:xamppDirCur
$xamppVersion = $env:xamppVersion


Import-Module (Join-Path $rootDir "etc\includes\UIHelpers.psm1") -Force
Import-Module (Join-Path $rootDir "etc\includes\alert.psm1") -Force
Import-Module (Join-Path $rootDir "etc\includes\addinputrow.psm1") -Force
Import-Module (Join-Path $rootDir "etc\includes\compareArchive.psm1") -Force

$themeFile = Join-Path $rootDir "data\theme.txt"
$currentMode = Import-ThemeState -themeFile $themeFile
$today = Get-Date -Format "yyyy-MM-dd"
$year = Get-Date -Format "yyyy"
$filePath = Join-Path $rootDir "data\buttons.txt"

$curDrvLtr = (Get-Item $curDrv).PSDrive.Name + ":"
$htdocsPath = Join-Path $curDrvLtr $Htdocs

$DefaultBackup = "\\hpdesktop\sandbox\postalsupply\backups\$year"

# load entries from file
$entries = @()
if (Test-Path $filePath) {
    Get-Content $filePath | ForEach-Object {
	$fields = $_ -split '\|'
	if ($fields.Count -ge 4) {
	    $entries += $fields[3]
	}
    }
}

# get folder name from url

function Get-FolderName {
    param (
        [Parameter(Mandatory)]
        [string]$InputPath
    )

    # Trim trailing slashes
    $cleanPath = $InputPath.TrimEnd('\','/')

    if ($cleanPath -match '^(https?://)') {
        # Handle as full URL
        try {
            $uri = [Uri]$cleanPath
            return ($uri.AbsolutePath.Trim('/') -split '/')[-1]
        }
        catch {
            Write-Warning "Invalid URL format: $InputPath"
            return $null
        }
    }
    elseif ($cleanPath -match '/') {
        # Handle as web-style path (e.g. localhost/postalsupply)
        return ($cleanPath -split '/')[-1]
    }
    else {
        # Handle as Windows-style path
        return Split-Path $cleanPath -Leaf
    }
}

$global:inputWidth += 100
$global:browseLeft += 100
$global:formWidth  += 100

$form = New-Object System.Windows.Forms.Form
$form.Font = $global:FontRegular
$form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Font
$form.Text = "xmenu WordPress backup maintenance"
$form.Size = New-Object System.Drawing.Size($global:formWidth, 376)
$form.TopMost = $true
$form.StartPosition = "CenterScreen"
$form.KeyPreview = $true   # Allows Enter/Esc handling
Set-FormTheme -Form $form -Mode $currentMode
# --------------------------------------------
# Create a label to display the current directory
# --------------------------------------------
$dirLabel = New-Object System.Windows.Forms.Label
$dirLabel.Text = "Current Directory: $xamppDirCur"
$dirLabel.Size = New-Object System.Drawing.Size(300, 20)
$dirLabel.Location = New-Object System.Drawing.Point(500, 10)
$dirLabel.Font = New-Object System.Drawing.Font('Arial', 8)
$dirLabel.ForeColor = [System.Drawing.Color]::Black
$dirLabel.AutoSize = $true
Set-LabelStyle -Label $dirLabel -Mode $currentMode
$form.Controls.Add($dirLabel)
# --------------------------------------------
# Create and add a label for displaying the PHP version
# --------------------------------------------
$phpVersionLabel = New-Object System.Windows.Forms.Label
$phpVersionLabel.Text = "PHP Version: $xamppVersion"
$phpVersionLabel.Size = New-Object System.Drawing.Size(300, 20)
$phpVersionLabel.Location = New-Object System.Drawing.Point(500, 25)
$phpVersionLabel.Font = New-Object System.Drawing.Font('Arial', 8)
$phpVersionLabel.ForeColor = [System.Drawing.Color]::Black
$phpVersionLabel.AutoSize = $true
Set-LabelStyle -Label $phpVersionLabel -Mode $currentMode
$form.Controls.Add($phpVersionLabel)

$labelSel = New-Object System.Windows.Forms.Label
$labelSel.Text = "Select both backup files, hold (shift or ctl) key and click files:"
$labelSel.Location = New-Object System.Drawing.Point(150,50)
$labelSel.AutoSize = $true
Set-LabelStyle -Label $labelSel -Mode $currentMode
$form.Controls.Add($labelSel)


# --------------------------------------------
# Request Backup Files to process
# --------------------------------------------
$backupFiles,$label = Add-InputRow $form "Backup Files:"   80  "listbox"
$backupFiles.HorizontalScrollbar = $true
# $backupFiles.ScrollAlwaysVisible = $true

$browseButton,$label = Add-InputRow $form "" 80  "browse"
$browseButton.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Multiselect = $true
    $dlg.Filter = "All files (*.*)|*.*"
    $dlg.InitialDirectory = 'D:\Downloads'

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
# Request location of Website folder on server
# --------------------------------------------
$websiteFolder, $websiteLabel = Add-InputRow $form "Website Folder:" 166 "comboBox"
# Populate $folderBox1 with subdirectories in each "...\htdocs" path
$namesToExclude = @("dashboard", "img", "webalizer", "xampp", "moac", "moac1")
if (Test-Path $htdocsPath) {
    Get-ChildItem -Path $htdocsPath -Directory | ForEach-Object {
	if ($namesToExclude -notcontains $_.Name) {
	    $websiteFolder.Items.Add((Join-Path $htdocsPath $_.Name)) | Out-Null
	}
    }
} else {
    Show-Alert -Message "Could not locate path to website directory: $htdocsPath"
    return
}

# ------------------------------------------------------------------
# Checkbox: Delete contents of htdocs website folder before copying
# ------------------------------------------------------------------
$delContents, $label = Add-InputRow $form "" 196 "checkbox"
$delContents.Text = "Delete Contents before copy"
$delContents.Checked = $true

# --------------------------------------------
# Checkbox: Save to backup folder
# --------------------------------------------
$backupCheckbox, $label = Add-InputRow $form "" 226 "checkbox"
$backupCheckbox.Text = "Save to Backup Folder"

# --------------------------------------------
# Optional Request folder to store Backup Files
# --------------------------------------------

$backupFolder, $folderLabelBkp = Add-InputRow $form "Backup Folder" 266 "textbox"
$backupFolder.Text = $DefaultBackup  # Default path for backup folder

$browseButtonBkp, $Label = Add-InputRow $form "" 266 "browse"
$browseButtonBkp.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.SelectedPath = $rootDir
    # $dlg.SelectedPath = [Environment]::GetFolderPath("MyDocuments")
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
	if ($dateCheckbox.checked) {
	    $backupFolder.Text = Join-Path $dlg.SelectedPath $today
	} else {
	    $backupFolder.Text = $dlg.SelectedPath
        }
    }
}.GetNewClosure())


# --------------------------------------------
# Checkbox: add date to backup folder name
# --------------------------------------------
$dateCheckbox, $label = Add-InputRow $form "" 306 "checkbox"
$dateCheckbox.text = "Add folder yyyy-mm-dd"


# --------------------------------------------
# Hide by default backup folder and display
# when checkbox is checked
# --------------------------------------------
# Hide backup folder controls by default
$backupFolder.Visible      = $false
$browseButtonBkp.Visible = $false
$folderLabelBkp.Visible  = $false
$dateCheckbox.Visible  = $false

$backupCheckbox.Add_CheckedChanged({
    $isVisible = $backupCheckbox.Checked
    $backupFolder.Visible      = $isVisible
    $browseButtonBkp.Visible = $isVisible
    $folderLabelBkp.Visible  = $isVisible
    $dateCheckbox.Visible    = $isVisible
    if ($isVisible) {
	$okButton.Location = New-Object System.Drawing.Point(250, 346)
	$cancelButton.Location = New-Object System.Drawing.Point(340, 346)
	$form.Size = New-Object System.Drawing.Size($global:formWidth, 446)
    } else {
	$okButton.Location = New-Object System.Drawing.Point(250, 276)
	$cancelButton.Location = New-Object System.Drawing.Point(340, 276)
	$form.Size = New-Object System.Drawing.Size($global:formWidth, 376)
    }
})

$dateCheckbox.Add_CheckedChanged({
    if ($backupFolder.Tag) {
	$path = $($backupFolder.Tag.SelPath)
    } else {
	$path = $DefaultBackup 
    }

    if ($path) {
	$isVisible = $dateCheckbox.Checked
	if ($isVisible) {
	    $backupFolder.Text = Join-Path $path $today
	} else {
	    $backupFolder.Text = $path
	}
    }
})


# OKButton
$okButton = New-Object System.Windows.Forms.Button
$okButton.Text = "OK"
$okButton.Location = New-Object System.Drawing.Point(250, 276)
$okButton.Size = New-Object System.Drawing.Size(80, 30)
Set-ButtonStyle -Button $okButton -Mode $currentMode
$form.Controls.Add($okButton)

$okButton.Add_Click({

    # Identify the installer.php file and the archive file (either .daf or .zip)
    # $files = @($backupFiles.Items | Where-Object { $_.Trim() -ne "" })
    $files = @($backupFiles.Items | ForEach-Object { $_.ToString() } | Where-Object { $_.Trim() -ne "" })
    
    if ($files.Count -ne 2) {
	Show-Alert -Message "Exactly 2 files are required."
	return
    }

    $installer	 = $files | Where-Object { [System.IO.Path]::GetFileName($_) -ieq "installer.php" }
    $archive   = $files | Where-Object { $_ -match '\.(daf|zip)$' }
   
    
    if (-not $installer -or -not $archive) {
	Show-Alert -Message "You must select installer.php and a .daf or .zip archive."
	return
    }

    
    if ([string]::IsNullOrWhiteSpace($websiteFolder.Text) -or -not (Test-Path $websiteFolder.Text)) {
	Show-Alert -Message "Enter valide website folder"
	return
    }

     if ($backupCheckbox.Checked -and [string]::IsNullOrWhiteSpace($backupFolder.Text)) {
        Show-Alert -Message "You must enter a valid backup folder."
        return
    }

    $form.Tag = @{
        Installer     = $installer
        Archive       = $archive
        WebsiteFolder = $websiteFolder.Text
        DeleteFiles   = $delContents.Checked
        BackupFolder  = if ($backupCheckbox.Checked) { $backupFolder.Text } else { "none" }
    }
    $form.Close()
})

$cancelButton = New-Object Windows.Forms.Button
$cancelButton.Text = 'Cancel'
$cancelButton.Location = New-Object System.Drawing.Point(340, 276)
$cancelButton.Size = New-Object System.Drawing.Size(80, 30)
Set-ButtonStyle -Button $cancelButton -Mode $currentMode
$form.Controls.Add($cancelButton)




# --- Cancel button click ---
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

# Show form
$form.ShowDialog() | Out-Null

if (-not $form.Tag) {
    Write-Output "cancel"
    exit
}
	
# Process selected values
if ($form.Tag) {

    $Installer     = $form.Tag.Installer
    $Archive       = $form.Tag.Archive
    $WebsiteFolder = $form.Tag.WebsiteFolder
    $DeleteFiles   = $form.Tag.DeleteFiles
    $BackupFolder  = $form.Tag.BackupFolder

    # Build localhost URL
    $afterHtdocs = ($WebsiteFolder -split '\\htdocs\\')[1]
    $url = "localhost/$afterHtdocs"

    Write-Host "Installer: $Installer"
    Write-Host "Archive: $Archive"
    Write-Host "WebsiteFolder: $WebsiteFolder"
    Write-Host "DeleteFiles: $DeleteFiles"
    Write-Host "BackupFolder: $BackupFolder"
    Write-Host "URL: $url"

    # -----------------------------
    # Validate files/folders
    # -----------------------------
    if ([string]::IsNullOrWhiteSpace($Installer) -or -not (Test-Path $Installer)) {
        Show-Alert -Message "Installer file not found."
        exit
    }

    if ([string]::IsNullOrWhiteSpace($Archive) -or -not (Test-Path $Archive)) {
        Show-Alert -Message "Archive file not found."
        exit
    }

    if ([string]::IsNullOrWhiteSpace($WebsiteFolder) -or -not (Test-Path $WebsiteFolder)) {
	Show-Alert -Message "Website folder not found."
    exit
}


    # -----------------------------
    # Delete existing files
    # -----------------------------
    if ($DeleteFiles) {

        $result = Show-Alert `
            -Message "Delete ALL contents from:`n$WebsiteFolder ?" `
            -Title "Confirmation" `
            -Buttons YesNo `
            -Batch

        if ($result -match '^yes$') {

            try {

		 
                Get-ChildItem $WebsiteFolder -Force |
		    Remove-Item -Force -Recurse -ErrorAction Stop

                Write-Host "Website folder cleaned."
            }
            catch {
                Show-Alert -Message "Error deleting files:`n$_"
                exit
            }
        }
        else {
            exit
        }
    }

    # -----------------------------
    # Copy files to website folder
    # -----------------------------
    try {

        Copy-Item $Installer -Destination $WebsiteFolder -Force
        Copy-Item $Archive   -Destination $WebsiteFolder -Force

        Write-Host "Files copied to website folder."
    }
    catch {
        Show-Alert -Message "Copy failed:`n$_"
        exit
    }

    # -----------------------------
    # Backup folder copy
    # -----------------------------
    if ($BackupFolder -ne "none") {

        if (-not (Test-Path $BackupFolder)) {

            New-Item `
                -ItemType Directory `
                -Path $BackupFolder `
                -Force | Out-Null
        }

        try {

            Copy-Item $Installer -Destination $BackupFolder -Force
            Copy-Item $Archive   -Destination $BackupFolder -Force

            Write-Host "Backup files copied."
        }
        catch {
            Show-Alert -Message "Backup copy failed:`n$_"
        }
    }

    # -----------------------------
    # Launch installer URL
    # -----------------------------
    $website = "http://$url/installer.php"

    Write-Host "Launching: $website"

    Start-Process $website

    Show-Alert -Message "Installer launched in browser."
}
