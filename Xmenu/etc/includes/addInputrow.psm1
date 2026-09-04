Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing


[int]$global:labelLeft = 20
[int]$global:labelLeft2 = 400
[int]$global:inputLeft = 200

[int]$global:inputWidth = 460
[int]$global:inputHght = 36
[int]$global:buttonwidth = 150
[int]$global:buttonHght = 30
[int]$global:comboWidth = 250
[int]$global:browseLeft = $global:inputLeft + $global:inputWidth + 10



#
#  Function to add an input row
#
function Add-InputRow {
   param (
	[System.Windows.Forms.Form]$Form,
        [string]$labelText,
        [int]$top,
        [ValidateSet('combobox','textbox','browse','checkbox','listbox',$null)]
        [string]$inputType
    )

    $label   = $null
    $control = $null

    if ($labelText) {
        $label = New-Object System.Windows.Forms.Label
        $label.Text = $labelText
        $label.Location = New-Object System.Drawing.Point($global:labelLeft, $top)
        $label.AutoSize = $true
        Set-LabelStyle -Label $label -Mode $currentMode
        $form.Controls.Add($label)
    }

    if ($inputType -eq 'combobox') {
        $control = New-Object System.Windows.Forms.ComboBox
        $control.Location = New-Object System.Drawing.Point($global:inputLeft, $top)
        $control.Size = New-Object System.Drawing.Size($global:inputWidth, 36)
        $control.DropDownStyle = 'DropDownList'
        Set-ComboBoxStyle -ComboBox $control -Mode $currentMode
        $form.Controls.Add($control)
    }

    elseif ($inputType -eq 'textbox') {
        $control = New-Object System.Windows.Forms.TextBox
        $control.Location = New-Object System.Drawing.Point($global:inputLeft, $top)
        $control.Size = New-Object System.Drawing.Size($global:inputWidth, 36)
        $control.ScrollBars = 'Vertical'
        Set-TextboxStyle -Textbox $control -Mode $currentMode
        $form.Controls.Add($control)
    }

    elseif ($inputType -eq 'browse') {
        $control = New-Object System.Windows.Forms.Button
        $control.Text = "Browse"
        $control.Location = New-Object System.Drawing.Point($global:browseLeft, $top)
        $control.Size = New-Object System.Drawing.Size(80, 23)
        Set-ButtonStyle -Button $control -Mode $currentMode
        $form.Controls.Add($control)
    }

    elseif ($inputType -eq 'checkbox') {
        $control = New-Object System.Windows.Forms.CheckBox
        $control.Location = New-Object System.Drawing.Point($global:inputLeft, $top)
        $control.AutoSize = $true
        Set-CheckboxStyle -Checkbox $control -Mode $currentMode
        $form.Controls.Add($control)
    }
    elseif ($inputType -eq 'listbox') {
	$control = New-Object System.Windows.Forms.ListBox
$control.SelectionMode = 'MultiExtended'
$control.Location = New-Object System.Drawing.Point($global:inputLeft, $top)
$control.Size = New-Object System.Drawing.Size($global:inputWidth, 72)
Set-ListBoxStyle -ListBox $control -Mode $currentMode
$form.Controls.Add($control)
    
    }

    return @($control, $label)
}
#
#  End of Function
#
