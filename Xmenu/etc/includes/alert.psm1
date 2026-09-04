Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Show-Alert {
    param (
	[string]$Message,
	[string]$Title = "Alert",
	[ValidateSet("OK","OKCancel","YesNo","RetryCancel")]
	[string]$Buttons = "OK"
    )

    # --- Create Form ---
    $form = New-Object Windows.Forms.Form
    $form.Font = $global:FontBold
    $form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Font
    $form.Text = $Title
    $form.StartPosition = 'CenterScreen'
    $form.TopMost = $true
    $form.AutoSize = $true
    $form.AutoSizeMode = 'GrowAndShrink'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MinimizeBox = $false
    $form.MaximizeBox = $false
    Set-FormTheme -Form $form -Mode $currentMode
    
    # --- Layout Panel ---
    $panel = New-Object Windows.Forms.FlowLayoutPanel
    $panel.Dock = 'Fill'
    $panel.Padding = '20,20,20,20'
    $panel.AutoSize = $true
    $panel.AutoSizeMode = 'GrowAndShrink'
    $panel.FlowDirection = 'TopDown'
    $panel.WrapContents = $false
    $form.Controls.Add($panel)

    # --- Message Label ---
    $label = New-Object Windows.Forms.Label
    $label.Text = $Message
    $label.AutoSize = $true
    $label.MaximumSize = New-Object Drawing.Size(400,0)  # wrap text if too long
    Set-LabelStyle -Label $Label -Mode $currentMode
    $panel.Controls.Add($label)

    # --- Buttons Panel ---
    $buttonsPanel = New-Object Windows.Forms.FlowLayoutPanel
    $buttonsPanel.FlowDirection = 'RightToLeft'
    $buttonsPanel.Dock = 'Bottom'
    $buttonsPanel.AutoSize = $true
    $buttonsPanel.Padding = '0,10,0,0'
    $panel.Controls.Add($buttonsPanel)

    $global:result = $null

    switch ($Buttons) {
	"OK" {
	    $ok = New-Object Windows.Forms.Button
	    $ok.Text = "OK"
	    Set-ButtonStyle -Button $ok -Mode $currentMode
	    $ok.Add_Click({ $global:result = 'OK'; $form.Close() })
	    $buttonsPanel.Controls.Add($ok)
	}
	"OKCancel" {
	    $ok = New-Object Windows.Forms.Button
	    $ok.Text = "OK"
	    Set-ButtonStyle -Button $ok -Mode $currentMode
	    $ok.Add_Click({ $global:result = 'OK'; $form.Close() })
	    $cancel = New-Object Windows.Forms.Button
	    $cancel.Text = "Cancel"
	    Set-ButtonStyle -Button $cancel -Mode $currentMode
	    $cancel.Add_Click({ $global:result = 'Cancel'; $form.Close() })
	    $buttonsPanel.Controls.AddRange(@($cancel, $ok))
	}
	"YesNo" {
	    $yes = New-Object Windows.Forms.Button
	    $yes.Text = "Yes"
	    Set-ButtonStyle -Button $yes -Mode $currentMode
	    $yes.Add_Click({ $global:result = 'Yes'; $form.Close() })
	    $no = New-Object Windows.Forms.Button
	    $no.Text = "No"
	    Set-ButtonStyle -Button $no -Mode $currentMode
	    $no.Add_Click({ $global:result = 'No'; $form.Close() })
	    $buttonsPanel.Controls.AddRange(@($no, $yes))
	}
	"RetryCancel" {
	    $retry = New-Object Windows.Forms.Button
	    $retry.Text = "Retry"
	    Set-ButtonStyle -Button $retry -Mode $currentMode
	    $retry.Add_Click({ $global:result = 'Retry'; $form.Close() })
	    $cancel = New-Object Windows.Forms.Button
	    $cancel.Text = "Cancel"
	    Set-ButtonStyle -Button $cancel -Mode $currentMode
	    $cancel.Add_Click({ $global:result = 'Cancel'; $form.Close() })
	    $buttonsPanel.Controls.AddRange(@($cancel, $retry))
	}
    }

    # --- Show Dialog ---
    $form.Add_Shown({
	$this.Activate()
	$this.BringToFront()
    })
    $form.ShowDialog() | Out-Null

    return $global:result
}
