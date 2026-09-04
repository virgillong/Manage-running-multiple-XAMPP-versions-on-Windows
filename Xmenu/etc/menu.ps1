param(
    [switch]$StartMinimized  # optional switch parameter
)

# Load the necessary assemblies for Windows Forms
Add-Type -AssemblyName "System.Windows.Forms"
Add-Type -AssemblyName "System.Drawing"

# Default path fallback for rootDir
if (-not $env:rootDir) {
    $env:rootDir = "$PSScriptRoot"
}

Import-Module (Join-Path $env:rootDir "etc\includes\UIHelpers.psm1") -Force
Import-Module (Join-Path $env:rootDir "etc\helpers\WinFormsEnumHelper.psm1") -Force

# File paths
$selectionFile = Join-Path $env:rootDir "data\menusel.txt"
$themeFile = Join-Path $env:rootDir "data\theme.txt"
# Load and apply theme
$currentMode = Import-ThemeState -themeFile $themeFile

# Create the form
$form = New-Object System.Windows.Forms.Form
$form.Font = $global:FontRegular
$form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Font
$form.Text = 'XMENU Website Management'
$form.Size = New-Object System.Drawing.Size(400, 330)
$form.StartPosition = 'CenterScreen'
$form.BackColor = [System.Drawing.Color]::LightBlue
$form.FormBorderStyle = 'Sizable'
$form.MaximizeBox = $true 
$form.MinimizeBox = $true
if ($StartMinimized) {
    $form.WindowState = 'Minimized'
} else {
    $form.WindowState = 'Normal'
}
# $form.TopMost = $true
$form.SuspendLayout()
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
$dividerLabel.Text = "______________________________________"
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

# Function to create styled buttons
function Create-Button($text, $locationY) {
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $text
    $button.Size = New-Object System.Drawing.Size(450, 30)
    $button.Location = New-Object System.Drawing.Point(100, $locationY)
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.FlatAppearance.BorderSize = 0
    $button.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
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

        try {
            # Disable button while processing
            $button.Enabled = $false
	    $global:selectedChoice = $selectionId 
	    
        }
        catch {
            # Catch and log any errors
            Write-Host "Error in click handler: $_"
        }
        finally {
            # Always re-enable the button
            $button.Enabled = $true
	    $form.Close()
        }

    }.GetNewClosure()
}

# Load buttons from file
$buttonFile = Join-Path $env:rootDir "data\buttons.txt"
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

    # Create a value-captured variable in this iteration scope
    $idCopy = $selectionId

    $btn.Add_Click( 
	(New-ClickHandler -selectionId $selectionId -button $btn) 
    )

    $buttons += $btn
    $index++
}

# $incrementedId = $null
# if ([int]::TryParse($selectionId, [ref]$null)) {
#    $incrementedId = [int]$selectionId + 1
#    # You can now use $incrementedId in another statement
# }

$y = $startY + ($spacing * $index)
$btn = Create-Button "Shutdown and exit" $y
$btn.Add_Click({ Save-Selection  "x"})
$buttons += $btn
$index++


# $incrementedId++
$y = $startY + ($spacing * $index)
$btn = Create-Button "Utilities" $y
$btn.Add_Click({ Save-Selection "u"})
$buttons += $btn
$index++

foreach ($btn in $buttons) {
    Set-ButtonStyle -Button $btn -Mode $currentMode
    [void]$form.Controls.Add($btn)
}

# Add buttons to the form
$buttons | ForEach-Object { $form.Controls.Add($_) }

# Responsive layout on resize
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

# Resume layout first
$form.ResumeLayout($true)
$form.PerformLayout()

# Use last button to determine needed height
$bottomMostButton = $buttons[-1]
$neededHeight = $bottomMostButton.Bottom + 70  # 70 = bottom padding

# Apply it after layout is finalized
$form.Height = $neededHeight

# Show the form
$form.ShowDialog() | Out-Null
Write-Output $global:selectedChoice
