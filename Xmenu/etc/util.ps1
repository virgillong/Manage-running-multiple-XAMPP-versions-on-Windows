# Load the necessary assemblies for Windows Forms
Add-Type -AssemblyName "System.Windows.Forms"
Add-Type -AssemblyName "System.Drawing"

# Default path fallback for rootDir
if (-not $env:rootDir) {
    $env:rootDir = (Resolve-Path "$PSScriptRoot\..").Path
}
$rootDir = $env:rootDir 

Import-Module (Join-Path $env:rootDir "etc\includes\UIHelpers.psm1") -Force

function Save-ThemeState($isDark) {
    $mode = if ($isDark) { "dark" } else { "light" }
    Set-Content  $themeFile $mode
}

# File paths
$themeFile = Join-Path $env:rootDir "data\theme.txt"

# Load and apply theme
$currentMode = Import-ThemeState -themeFile $themeFile


# Create the form
$form = New-Object System.Windows.Forms.Form
$form.Font = $global:FontRegular
$form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Font
$form.Text = 'xmenu Utilities'
$form.Size = New-Object System.Drawing.Size(500, 460)
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$form.BackColor = [System.Drawing.Color]::LightBlue
$form.FormBorderStyle = 'Sizable'
$form.MaximizeBox = $false
$form.MinimizeBox = $true
$form.TopMost = $true
Set-FormTheme -Form $form -Mode $currentMode

# Create a label to display the current directory
$dirLabel = New-Object System.Windows.Forms.Label
$dirLabel.Text = "Current Directory: $env:xamppDirCur"
$dirLabel.Location = New-Object System.Drawing.Point(300, 10)
$dirLabel.Font = New-Object System.Drawing.Font('Arial', 8)
$dirLabel.ForeColor = [System.Drawing.Color]::Black
$dirLabel.AutoSize = $true
Set-LabelStyle -Label $dirLabel -Mode $currentMode
$form.Controls.Add($dirLabel)

# Create and add a label for displaying the PHP version
$phpVersionLabel = New-Object System.Windows.Forms.Label
$phpVersionLabel.Text = "PHP Version: $env:xamppVersion"
$phpVersionLabel.Location = New-Object System.Drawing.Point(300, 30)
$phpVersionLabel.Font = New-Object System.Drawing.Font('Arial', 8)
$phpVersionLabel.AutoSize = $true
Set-LabelStyle -Label $phpVersionLabel -Mode $currentMode
if ($env:xamppVersion -match 'unavailable') {
    $phpVersionLabel.forecolor = "red"
}
$form.Controls.Add($phpVersionLabel)

# Create and add a label for displaying the mysql version
$sqlVersionLabel = New-Object System.Windows.Forms.Label
$sqlVersionLabel.Text = "MySQL Version: $env:sqlVersion"
$sqlVersionLabel.Location = New-Object System.Drawing.Point(300, 50)
$sqlVersionLabel.Font = New-Object System.Drawing.Font('Arial', 8)
$sqlVersionLabel.AutoSize = $true
Set-LabelStyle -Label $sqlVersionLabel -Mode $currentMode
if ($env:sqlVersion -match 'unavailable') {
    $sqlVersionLabel.forecolor = "red"
}

$form.Controls.Add($sqlVersionLabel)

# Create and add a label for displaying divider
$dividerLabel = New-Object System.Windows.Forms.Label
$dividerLabel.Text = "________________________________________________"
$dividerLabel.Location = New-Object System.Drawing.Point(20, 60)
$dividerLabel.AutoSize = $true
$Label.ForeColor = "gray"
$form.Controls.Add($dividerLabel)

# Create a label for "Select Menu Item"
$label = New-Object System.Windows.Forms.Label
$label.Text = "Select Menu Item:"
$label.Location = New-Object System.Drawing.Point(10, 85)
$label.AutoSize = $true
Set-LabelStyle -Label $label -Mode $currentMode
$form.Controls.Add($label)


# Function to create buttons (making sure they are of correct type)
function Create-Button($text, $locationY) {
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $text
    $button.Size = New-Object System.Drawing.Size(450, 30)
    $button.Location = New-Object System.Drawing.Point(50, $locationY)
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.FlatAppearance.BorderSize = 0
    $button.TextAlign = [System.Drawing.ContentAlignment]::Middleleft
    $button.Anchor = 'Top,Left,Right'
    return $button
}


function New-ClickHandler {
    param(
        [string]$selectionId,
        [System.Windows.Forms.Button]$button
    )

    return [System.EventHandler]{
        param($sender, $eventArgs)
	# Disable button while processing
	$button.Enabled = $false
	$form.Refresh()   # <-- forces UI to update immediately
        
	try {
            # Save selection
            # $global:selectedChoice = $selectionId
	    Save-Selection $selectionId
        }
        catch {
            Write-Host "Error in click handler: $_"
        }
        finally {
            # re-enable button
	    $button.Enabled = $true
        }

    }.GetNewClosure()
}


# Load buttons from file
$buttonFile = Join-Path $env:rootDir "data\buttons-util.txt"
$buttonData = Get-Content $buttonFile | Where-Object { $_ -match '\|' }

$buttons = @()
$startY = 120
$spacing = 40
$index = 0

foreach ($line in $buttonData) {
    $parts = $line -split '\|'
    $labelText = (Invoke-Expression "`"$($parts[0])`"")  # Allows env vars in labels
    $selectionId = $parts[1].Trim()

    $y = $startY + ($spacing * $index)
    $btn = Create-Button $labelText $y
    $btn.Add_Click( 
	(New-ClickHandler -selectionId $selectionId -button $btn) 
    )
    $buttons += $btn
    $index++
}

$y = $startY + ($spacing * $index)
$index++
$btn = Create-Button "Manage Menu Buttons" $y
$btn.Add_Click({ 
    Save-Selection  "0"
    $scriptPath = (Join-Path $env:rootDir "etc\menuMaint.ps1")
    $form.Hide()  # Hide the main form
    . $scriptPath
    $form.Show()  # Show main form again when submenu closes
})
$buttons += $btn

$y = $startY + ($spacing * $index)
$toggleButton=$index
$index++
$btn = Create-Button  "Toggle Theme" $y
$btn.Add_Click({  
    $currentTheme = Import-ThemeState -themeFile $themeFile
    $isDark = $currentTheme -ne "dark"
   
    Save-ThemeState $isDark
    $mode = if ($isDark) { "dark" } else { "light" }
    Set-FormTheme -Form $form -Mode  $mode

    foreach ($btn in $buttons) {
	Set-ButtonStyle -Button $btn -Mode $mode
    }
    Set-LabelStyle -Label $phpVersionLabel -Mode $Mode
    Set-LabelStyle -Label $dirLabel -Mode $Mode
    Set-LabelStyle -Label $label -Mode $Mode
    if ($isDark) {
	$buttons[$toggleButton].Text = "Toggle Light Theme"
    } else {
	$buttons[$toggleButton].Text = "Toggle Dark Theme"
    }
    
}) 
$buttons += $btn

$y = $startY + ($spacing * $index)
$index++
$btn = Create-Button  "Main Menu" $y
$btn.Add_Click({ Save-Selection  "D"})
$buttons += $btn


foreach ($btn in $buttons) {
    Set-ButtonStyle -Button $btn -Mode $currentMode
    [void]$form.Controls.Add($btn)
}

$form.Add_Resize({
    $padding = 100
    $newWidth = [Math]::Max(200, $form.ClientSize.Width - $padding)

    # Resize buttons
    for ($i = 0; $i -lt $buttons.Count; $i++) {
        $buttons[$i].Width = $newWidth
        $buttons[$i].Left  = ($form.ClientSize.Width - $newWidth)
    }

    # --- Right-aligned labels --- #

    $rightMargin = 20   # 20px margin from right is more standard

    # Clamp so Left never becomes negative
    $dirLabel.Left = [Math]::Max(0, $form.ClientSize.Width - $rightMargin - $dirLabel.Width)
    $phpVersionLabel.Left = [Math]::Max(0, $form.ClientSize.Width - $rightMargin - $phpVersionLabel.Width)
    $sqlVersionLabel.Left = [Math]::Max(0, $form.ClientSize.Width - $rightMargin - $sqlVersionLabel.Width)
})

# Use last button to determine needed height
$bottomMostButton = $buttons[-1]
$neededHeight = $bottomMostButton.Bottom + 70  # 70 = bottom padding

# Apply it after layout is finalized
$form.Height = $neededHeight


# Show the form
$form.ShowDialog() | Out-Null

Write-Output $global:selectedChoice