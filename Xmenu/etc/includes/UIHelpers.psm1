Add-Type -AssemblyName System.Drawing

$global:FontRegular = New-Object System.Drawing.Font('Arial', 12, [System.Drawing.FontStyle]::Regular)
$global:FontBold = New-Object System.Drawing.Font('Arial', 12, [System.Drawing.FontStyle]::Bold)
$global:FontLabelReg = New-Object System.Drawing.Font('Arial', 15, [System.Drawing.FontStyle]::Regular)
$global:FontLabelBold = New-Object System.Drawing.Font('Arial', 15, [System.Drawing.FontStyle]::Bold)
$global:formWidth = 650


# =====================================================
# Selection & logging logic
# =====================================================
# Holds menu choice to return to batch
$global:selectedChoice = 0  # Holds menu choice to return to batch
$global:selectedWebAdd = $null  # Optional web address

function Save-Selection {
    param (
        [Parameter(Mandatory=$true)]
        [string]$code
    )
    # $MenuSelPath=Join-Path $env:rootDir "data\menusel.txt"
    # Set-Content -Path $MenuSelPath -Value $code -Encoding ASCII
    $global:selectedChoice = $code  
    $form.Close()
}

# =====================================================
# =====================================================
function Import-ThemeState {
    param (
	$themeFile
    )
    if (Test-Path $themeFile) {
        return (Get-Content $themeFile -Raw).Trim()
    } else {
        return "light"  # default mode
    }
}
# =====================================================
# =====================================================
function Enable-HoverEffect {
    param (
        [System.Windows.Forms.Button]$button,
        [System.Drawing.Color]$hoverColor,
        [System.Drawing.Color]$fontColor
    )
    if (-not $Button -or -not ($Button -is [System.Windows.Forms.Button])) {
	Write-Warning "Invalid or null button passed to Set-ButtonStyle"
	return
    }
    $button.Tag = [PSCustomObject]@{
        Original  = $button.BackColor
        Hover     = $hoverColor
        OrigFont  = $button.ForeColor
        FontClr   = $fontColor
    }

    $button.Add_MouseEnter({
        param ($sender, $e)
        $colors = $sender.Tag

        if ($null -ne $colors -and $colors.Hover -is [System.Drawing.Color]) {
            $sender.BackColor = $colors.Hover
            $sender.Font = New-Object System.Drawing.Font($sender.Font, [System.Drawing.FontStyle]::Bold)
        }

        if ($colors.FontClr -is [System.Drawing.Color]) {
            $sender.ForeColor = $colors.FontClr
        }
    })

    # Optional: MouseLeave to restore original colors/fonts
    $button.Add_MouseLeave({
        param ($sender, $e)
        $colors = $sender.Tag

        if ($null -ne $colors -and $colors.Original -is [System.Drawing.Color]) {
            $sender.BackColor = $colors.Original
            $sender.Font = New-Object System.Drawing.Font($sender.Font, [System.Drawing.FontStyle]::Regular)
        }

        if ($colors.OrigFont -is [System.Drawing.Color]) {
            $sender.ForeColor = $colors.OrigFont
        }
    })
}

# =====================================================
# =====================================================
function Set-ControlStyle {
    param (
        [Parameter(Mandatory=$true)]
        [System.Windows.Forms.Control]$Control,

        [System.Drawing.Color]$ForeColor,
        [System.Drawing.Color]$BackColor,
        [System.Drawing.FontStyle]$FontStyle
    )

    if ($null -eq $Control) { return }

    if ($PSBoundParameters.ContainsKey('ForeColor')) {
        $Control.ForeColor = $ForeColor
    }

    if ($PSBoundParameters.ContainsKey('BackColor')) {
        $Control.BackColor = $BackColor
    }

    if ($PSBoundParameters.ContainsKey('FontStyle')) {
        $Control.Font = New-Object System.Drawing.Font($Control.Font, $FontStyle)
    }
}

# =====================================================
# =====================================================
function Get-WindowsTheme {
    $theme = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    if ($theme.AppsUseLightTheme -eq 0) {
        return "Dark"
    } else {
        return "Light"
    }
}
# =====================================================
# =====================================================
function Set-FormTheme {
    param (
        [System.Windows.Forms.Form]$Form,
        [string]$Mode
    )
    $Form.BackColor = if ($Mode -eq 'dark') { "#2D2D30" } else { "LightSteelBlue" }
}
# =====================================================
# =====================================================
function Set-ButtonStyle {
    param (
        [System.Windows.Forms.Button]$Button,
        [string]$Mode
    )

    if (-not $Button -or -not ($Button -is [System.Windows.Forms.Button])) {
	Write-Warning "Invalid or null button passed to Set-ButtonStyle"
	return
}
    if ($Mode -eq 'dark') {
        $Button.ForeColor = "White"
        $Button.BackColor = "#444"
        Enable-HoverEffect -button $Button -hoverColor ([System.Drawing.Color]::FromArgb(100, 100, 100)) -fontColor "Black"
    } else {
        $Button.ForeColor = "Black"
        $Button.BackColor = "White"
        Enable-HoverEffect -button $Button -hoverColor ([System.Drawing.Color]::DarkGray) -fontColor "White"
    }
}

# =====================================================
# =====================================================
function Set-LabelStyle {
    param (
        [System.Windows.Forms.Label]$Label,
        [string]$Mode
    )
    $Label.ForeColor = if ($Mode -eq 'dark') { "White" } else { "Black" }
}

# =====================================================
# =====================================================
function Set-TextboxStyle {
    param (
        [System.Windows.Forms.TextBox]$Textbox,
        [string]$Mode
    )
    if ($Mode -eq 'dark') {
        $Textbox.BackColor = "#2D2D30"
        $Textbox.ForeColor = "White"
    } else {
        $Textbox.BackColor = "White"
        $Textbox.ForeColor = "Black"
    }
}

# =====================================================
# =====================================================
function Set-CheckboxStyle {
    param (
        [System.Windows.Forms.CheckBox]$Checkbox,
        [string]$Mode
    )
    if ($Mode -eq 'dark') {
        $Checkbox.BackColor = "#2D2D30"
        $Checkbox.ForeColor = "White"
    } else {
        $Checkbox.BackColor = "White"
        $Checkbox.ForeColor = "Black"
    }
}

# =====================================================
# =====================================================
function Set-RadioStyle {
    param (
        [System.Windows.Forms.RadioButton]$Radio,
        [string]$Mode
    )
    
    if ($Mode -eq 'dark') {
        $Radio.BackColor = "#2D2D30"
        $Radio.ForeColor = "White"
    } else {
        $Radio.BackColor = "White"
        $Radio.ForeColor = "Black"
    }
}

# =====================================================
# =====================================================
function Set-ListViewStyle {
    param (
        [System.Windows.Forms.ListView]$ListView,
        [string]$Mode
    )
    if ($Mode -eq 'dark') {
        $ListView.BackColor = "#1E1E1E"
        $ListView.ForeColor = "white"
        $ListView.GridLines = $false
    } else {
        $ListView.BackColor = "White"
        $ListView.ForeColor = "Black"
        $ListView.GridLines = $true
    }
    $ListView.BorderStyle = "FixedSingle"
}
# =====================================================
# =====================================================
function Set-ListBoxStyle {
    param (
        [System.Windows.Forms.ListBox]$listBox,
        [string]$Mode
    )
    if ($Mode -eq 'dark') {
	
       $listBox.BackColor = "#1E1E1E"
        $listBox.ForeColor = "white"
    } else {
        $listBox.BackColor = "White"
        $listBox.ForeColor = "Black"
    }
    $listBox.BorderStyle = "FixedSingle"
}
# =====================================================
# =====================================================
function Set-comboBoxStyle {
    param (
        [System.Windows.Forms.comboBox]$comboBox,
        [string]$Mode
    )
    if ($Mode -eq 'dark') {
        $comboBox.BackColor = "#2D2D30"
        $comboBox.ForeColor = "White"
    } else {
        $comboBox.BackColor = "White"
        $comboBox.ForeColor = "Black"
    }
}

