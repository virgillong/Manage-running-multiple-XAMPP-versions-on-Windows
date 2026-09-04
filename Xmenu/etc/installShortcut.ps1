Add-Type -AssemblyName 'System.Windows.Forms'
Add-Type -AssemblyName 'System.Drawing'

# Default path fallback for rootDir
if (-not $env:rootDir) {
    $env:rootDir = (Resolve-Path "$PSScriptRoot\..").Path
}
$rootDir = $env:rootDir 

Import-Module (Join-Path $rootDir "etc\includes\UIHelpers.psm1") -Force
Import-Module (Join-Path $rootDir "etc\includes\addinputrow.psm1") -Force

# File paths
$themeFile = Join-Path $rootDir "data\theme.txt"
$filePath = Join-Path $rootDir "data\buttons.txt"
$filePath1= Join-Path $rootDir "data\buttons-util.txt"
# Load theme mode from file
$currentMode = Import-ThemeState -themeFile $themeFile

$xamppIcon = Join-Path $rootDir "etc\icons\xampp.ico"
$xmenuIcon = Join-Path $rootDir "etc\icons\Xmenu1.ico"

# Load entries from file
if (Test-Path $filePath) {
    $entries = Get-Content $filePath | Where-Object { $_.Trim() -ne "" } |
    ForEach-Object {
        $fields = $_ -split '\|'
        [PSCustomObject]@{
            Name  = $fields[0]
            ID    = $fields[1]
            URL   = $fields[2]
            Path  = $fields[3]
        }
    }
}



$newEntry = [PSCustomObject]@{
    Name = "Xmenu"
    ID   = "xmenu"
    URL  = ""
    Path = ""
}
$entries += $newEntry

$newEntry = [PSCustomObject]@{
    Name = "Xutility"
    ID   = "u"
    URL  = ""
    Path = ""
}
$entries += $newEntry

# --- Form setup ---
$form = New-Object Windows.Forms.Form
$form.Font = $global:FontRegular
$form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Font
$form.Text = "Select Menu Item"
$form.Width = $global:formWidth
$form.Height = 220
$form.StartPosition = 'CenterScreen'
$form.KeyPreview = $true   # Allows Enter/Esc handling
Set-FormTheme -Form $form -Mode $currentMode


$topStrt = 30
$spacing = 40

$combo, $label = Add-InputRow $form "Menu Item"   $topStrt  "combobox"
$combo.Items.AddRange($entries.Name)

$top = (1*$spacing) + $topstrt

$labelid = New-Object Windows.Forms.Label
$labelid.Left = 150
$labelid.Top = $top
$labelid.AutoSize = $true
Set-LabelStyle -Label $Labelid -Mode $currentMode
$form.Controls.Add($labelid)

$top = (2*$spacing) + $topstrt

$textboxName, $labelName = Add-InputRow $form "ShortCut Name"   $top  "textbox"

$top = (3*$spacing) + $topstrt

$textboxicon, $labelicon = Add-InputRow $form "Icon File"  $top "textbox"
$browseIcon, $label = Add-InputRow $form ""   $top "browse"
$browseIcon.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Title = "Select a file"                # Custom title
    $dlg.InitialDirectory = Join-Path $rootDir "etc\icons"   # Default folder
    # $dlg.InitialDirectory = [Environment]::GetFolderPath('MyDocuments')  # Default folder
    $dlg.Filter = "icon Files (*.ico)|*.ico|All Files (*.*)|*.*"         # File type filters
    $dlg.FilterIndex = 1                        # Default to first filter
    $dlg.Multiselect = $false                   # Allow only one file
    $dlg.CheckFileExists = $true                # Ensure file exists before returning
    $dlg.CheckPathExists = $true
    $dlg.RestoreDirectory = $true               # Return to last folder next time
    $dlg.DefaultExt = "ico"                     # Default extension if none given

    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        # $dlg.FileName gives full path to the selected file
        # Write-Host "Selected file: $($dlg.FileName)"
        $textboxicon.Text = $dlg.FileName
    }
})

$top = (4*$spacing) + $topstrt

$okButton = New-Object Windows.Forms.Button
$okButton.Text = 'OK'
$okButton.Left = 300
$okButton.Top = $top
Set-ButtonStyle -Button $okButton -Mode $currentMode
$form.Controls.Add($okButton)

$cancelButton = New-Object Windows.Forms.Button
$cancelButton.Text = 'Cancel'
$cancelButton.Left = 390
$cancelButton.Top = $top

Set-ButtonStyle -Button $cancelButton -Mode $currentMode
$form.Controls.Add($cancelButton)

$form.AcceptButton = $okButton
$form.CancelButton = $cancelButton

# --- Events ---
$combo.Add_SelectedIndexChanged({
    $selectedName = $combo.SelectedItem
    $selected = $entries | Where-Object { $_.Name -eq $selectedName }
    if ($selected) {
	if (($selected.ID -eq "xmenu") -or ($selected.ID -eq "u")) {
	    $textboxicon.Text = $xmenuIcon
	} else {
	    $textboxicon.Text = $xamppIcon
	}
        $labelid.Text = "ID: " + $selected.ID
        $textboxName.Text = $selectedName


        $combo.Tag = [PSCustomObject]@{
            Sel = $selectedName
            ID  = $selected.ID
        }
    }
})

# --- OK button click ---
$okButton.Add_Click({
    if (-not $combo.SelectedItem) {
        [System.Windows.Forms.MessageBox]::Show("Please select a menu item.", "Missing Selection", 'OK', 'Warning')
        return
    }

    if ([string]::IsNullOrWhiteSpace($textboxName.Text)) {
        [System.Windows.Forms.MessageBox]::Show("Please enter a shortcut name.", "Missing Input", 'OK', 'Warning')
        return
    }

    $form.Tag = "OK"
    $form.Close()
})

# --- Cancel button click ---
$cancelButton.Add_Click({
    $form.Tag = "Cancel"
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

# --- Default selection (first entry) ---
if ($entries -and $entries.Count -gt 0) {
    $combo.SelectedIndex = 0
    # Trigger same behavior as manual selection
    $selected = $entries[0]
    $labelid.Text = "ID: " + $selected.ID
    $textboxName.Text = $selected.Name
    $combo.Tag = [PSCustomObject]@{
        Sel = $selected.Name
        ID  = $selected.ID
    }
}

# Adjust height based on buttons
$form.Height = $cancelButton.Bottom + 60


# --- Show form and handle result ---
$form.ShowDialog() | Out-Null

if ($form.Tag -eq "OK") {
    $menuName      = $combo.Tag.Sel
    $selectedId    = $combo.Tag.ID
    $shortcutName  = "$($textboxName.Text).lnk"
    $shortcutIcon  = $textboxicon.Text

    # ------------------------
    # Default config
    # ------------------------

    $psScript   = Join-Path $rootDir "etc\runHidden.ps1"
    $targetFile = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"

    $param = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$psScript`" -MenuID `"$selectedId`""

    # ------------------------
    # Debug output
    # ------------------------

    Write-Host "------------------------"
    Write-Host "menuName:     $menuName"
    Write-Host "selectedId:   $selectedId"
    Write-Host "shortcutName: $shortcutName"
    Write-Host "shortcutIcon: $shortcutIcon"
    Write-Host "targetFile:   $targetFile"
    Write-Host "------------------------"

    # ------------------------
    # Get Desktop path
    # ------------------------

    $desktopPath = [Environment]::GetFolderPath("Desktop")

    # ------------------------
    # Set shortcut path
    # ------------------------

    $shortcutPath = Join-Path $desktopPath $shortcutName

    # ------------------------
    # Verify script exists
    # ------------------------

    if (-not (Test-Path $psScript)) {
        Write-Host "ERROR: file not found at $psScript"
        Pause
        exit
    }

    # ------------------------
    # Create shortcut
    # ------------------------

    $WshShell = New-Object -ComObject WScript.Shell
    $shortcut = $WshShell.CreateShortcut($shortcutPath)

    $shortcut.TargetPath       = $targetFile
    $shortcut.Arguments        = $param
    $shortcut.WorkingDirectory = $rootDir
    $shortcut.IconLocation     = "$shortcutIcon,0"

    $shortcut.Save()

    # ------------------------
    # Notify
    # ------------------------

    Write-Host ""
    $message  = "Shortcut created on Desktop: $shortcutName"
    $inputMsg = $message

    & powershell.exe -ExecutionPolicy Bypass `
        -File (Join-Path $rootDir "etc\alert.ps1") `
        -Message $inputMsg
}
else {
    Write-Output "CANCEL"
    exit
}