function Show-ReorderWindow {
    param(
        [string]$FilePath
    )

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $reorder = New-Object System.Windows.Forms.Form
    $reorder.Font = $global:FontBold
    $reorder.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Font
    $reorder.Text = "Reorder Entries"
    $reorder.Size = "850,400"
    $reorder.StartPosition = "CenterParent"
     Set-FormTheme -Form $reorder -Mode $currentMode


    $list = New-Object System.Windows.Forms.ListBox
    $list.Size = "800,260"
    $list.Location = "15,15"
    $list.HorizontalScrollbar = $true
    Set-ListBoxStyle  -ListBox $list -Mode $currentMode
    $reorder.Controls.Add($list)

    # Load file
    Get-Content $FilePath | ForEach-Object { $list.Items.Add($_) }

    # Buttons
    $btnUp = New-Object System.Windows.Forms.Button
    $btnUp.Text = "Up"
    $btnUp.Location = "15,290"
    Set-ButtonStyle -Button $btnUp -Mode $currentMode
    $btnUp.Add_Click({
        $i = $list.SelectedIndex
        if ($i -gt 0) {
            $item = $list.SelectedItem
            $list.Items.RemoveAt($i)
            $list.Items.Insert($i-1, $item)
            $list.SelectedIndex = $i-1
        }
    })
    $reorder.Controls.Add($btnUp)

    $btnDown = New-Object System.Windows.Forms.Button
    $btnDown.Text = "Down"
    $btnDown.Location = "100,290"
    Set-ButtonStyle -Button $btnDown -Mode $currentMode
    $btnDown.Add_Click({
        $i = $list.SelectedIndex
        if ($i -ge 0 -and $i -lt $list.Items.Count - 1) {
            $item = $list.SelectedItem
            $list.Items.RemoveAt($i)
            $list.Items.Insert($i+1, $item)
            $list.SelectedIndex = $i+1
        }
    })
    $reorder.Controls.Add($btnDown)

    $btnSave = New-Object System.Windows.Forms.Button
    $btnSave.Text = "Save"
    $btnSave.Location = "200,290"
    Set-ButtonStyle -Button $btnSave -Mode $currentMode
    $btnSave.Add_Click({
        $list.Items | Set-Content $FilePath -Encoding UTF8
	 Show-Alert -Message "Order saved."  -Title "Confirmation"
        $reorder.Close()
    })
    $reorder.Controls.Add($btnSave)

    $reorder.ShowDialog() | Out-Null
}
