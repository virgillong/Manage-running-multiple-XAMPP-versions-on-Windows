param (
    [string]$inputMsg = 'Please select a file:',
    [string]$Title = 'Select File',
    # [string]$DefaultText = 'D:\xampp 8.1',
    [string]$showCheckbox = 'true',
    [string]$Checkboxtxt
)

Add-Type -AssemblyName 'System.Windows.Forms'
Add-Type -AssemblyName 'System.Drawing'

$showCheckboxBool = $true
if ($showCheckbox -match '^(1|false)$') {
    $showCheckboxBool = $false
}

# Default path fallback for rootDir
if (-not $env:rootDir) {
    $env:rootDir = "$PSScriptRoot"
}

Import-Module (Join-Path $env:rootDir "etc\includes\UIHelpers.psm1") -Force

# File paths
$selectionFile = Join-Path $env:rootDir "data\menusel.txt"
$themeFile = Join-Path $env:rootDir "data\theme.txt"

# Load theme mode from file
$currentMode = Import-ThemeState -themeFile $themeFile

$form = New-Object Windows.Forms.Form
$form.Font = $global:FontBold
$form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Font
$form.Text = $Title
$form.Width = 500
$form.Height = 220
$form.StartPosition = 'CenterScreen'
$form.TopMost = $true
Set-FormTheme -Form $form -Mode $currentMode

$label = New-Object Windows.Forms.Label
$label.Text = $inputMsg
$label.AutoSize = $true
$label.Left = 10
$label.Top = 30
Set-LabelStyle -Label $Label -Mode $currentMode

$textbox = New-Object Windows.Forms.TextBox
$textbox.Width = 350
$textbox.Left = 10
$textbox.Top = 50
$textbox.Text = $DefaultText
Set-TextboxStyle -Textbox $textbox -Mode $currentMode

$browseButton = New-Object Windows.Forms.Button
$browseButton.Text = "Browse..."
$browseButton.Left = 370
$browseButton.Top = 48
$browseButton.Width = 80

$okButton = New-Object Windows.Forms.Button
$okButton.Text = 'OK'
$okButton.Left = 300
$okButton.Top = 150
$okButton.DialogResult = [Windows.Forms.DialogResult]::OK

$cancelButton = New-Object Windows.Forms.Button
$cancelButton.Text = 'Cancel'
$cancelButton.Left = 390
$cancelButton.Top = 150
$cancelButton.DialogResult = [Windows.Forms.DialogResult]::Cancel

# Browse button opens FolderBrowserDialog
$browseButton.Add_Click({
    $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderDialog.SelectedPath = $textbox.Text
    $folderDialog.Description = "Select a folder"
    if ($folderDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $textbox.Text = $folderDialog.SelectedPath
    }
})

$form.Controls.AddRange(@($label, $textbox, $browseButton, $okButton, $cancelButton))
$form.AcceptButton = $okButton
$form.CancelButton = $cancelButton

$buttons = @($browseButton, $okButton, $cancelButton)
foreach ($btn in $buttons) {
    Set-ButtonStyle -Button $btn -Mode $currentMode
    [void]$form.Controls.Add($btn)
}



# Use last button to determine needed height
$bottomMostButton = $buttons[-1]
$neededHeight = $bottomMostButton.Bottom + 60 # 50 = bottom padding

# Apply it after layout is finalized
$form.Height = $neededHeight


$dialogResult = $form.ShowDialog()

if ($dialogResult -eq [Windows.Forms.DialogResult]::OK) {

    Write-Output $textbox.Text
    Write-Output $checkbox.Checked
    Write-Output $textboxName.Text

    # Output both selected text and checkbox value
    # [PSCustomObject]@{
    #    Path     = $textbox.Text
    #    Checked  = $checkbox.Checked
    #}

} else {
    Write-Output $null
}