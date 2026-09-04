Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic
if (-not $env:rootDir) {
    $env:rootDir = (Resolve-Path "$PSScriptRoot\..").Path
}
$rootDir = $env:rootDir 

Import-Module (Join-Path $rootDir "etc\includes\UIHelpers.psm1") -Force
Import-Module (Join-Path $rootDir "etc\includes\addinputrow.psm1") -Force

# Default path fallback for rootDir
if (-not $env:rootDir) {
    $env:rootDir = (Resolve-Path "$PSScriptRoot\..").Path
}
$rootDir = $env:rootDir 

if (-not $env:curDrv) {
    $env:curDrv = (Resolve-Path "$PSScriptRoot\..\..").Path
}
$curDrv = $env:curDrv 


function Normalize-PathSafe {
    param([string]$Path)

    if (-not $Path) { return $Path }

    # Bare drive letter → force root
    if ($Path -match '^[A-Za-z]:$') {
        return "$Path"
    }

    try {
        $resolved = (Resolve-Path -Path $Path).Path
    }
    catch {
        $resolved = [IO.Path]::GetFullPath($Path)
    }

    # If it's a root path, keep trailing backslash
    if ($resolved -match '^[A-Za-z]:\\$') {
        return $resolved
    }

    # UNC root: \\server\share\
    if ($resolved -match '^\\\\[^\\]+\\[^\\]+\\$') {
        return $resolved
    }

    # Everything else: trim trailing slash
    return $resolved.TrimEnd('\')
}


function Convert-ToTag {
    param(
        [string]$Path,
        [string]$CurDrv,
        [string]$Tag = '{DRIVE}'
    )

    $Path   = Normalize-PathSafe $Path
    $CurDrv = (Normalize-PathSafe $CurDrv).TrimEnd('\') + '\'

    if ($Path.StartsWith($CurDrv, [StringComparison]::InvariantCultureIgnoreCase)) {
        $relative = $Path.Substring($CurDrv.Length)
        $result = $Tag + "\" + $relative
        return $result
    }
    return $Path
}


function Convert-FromTag {
    param(
        [string]$Path,
        [string]$CurDrv,
        [string]$Tag = '{DRIVE}'
    )

    if ($Path.StartsWith($Tag, [StringComparison]::InvariantCultureIgnoreCase)) {
        $CurDrv = Normalize-PathSafe $CurDrv
        return $CurDrv + $Path.Substring($Tag.Length)
    }
    return $Path
}
 [int]$formHght = 350
 [int]$formWidth = 850
 [int]$listViewHght = 320

function Create-EntryForm($title, $selectedItem = $null) {
    $entryForm = New-Object Windows.Forms.Form
    $entryForm.Text = $title
    $entryForm.Size = New-Object System.Drawing.Size($formWidth,$formHght)
    $entryForm.StartPosition = 'CenterParent'
    $entryForm.FormBorderStyle = 'Sizable'
    $entryForm.MaximizeBox = $false
    $entryForm.MinimizeBox = $false
    Set-FormTheme -Form $entryForm -Mode $currentMode

    if ($global:mainMenu) {
        $labels = "Button", "ID", "URL", "Path to Xampp", "Path to custom file"
    } else {
        $labels = "Button", "ID", "Path to Executable", "URL"
    }

    $browseButtons = @()   # ← COLLECT BROWSE BUTTONS
    $textboxes = @{}
    $y = 20

    foreach ($labelText in $labels) {
        # Label
        $lbl = New-Object Windows.Forms.Label
        $lbl.Text = $labelText
        $lbl.Location = New-Object Drawing.Point($global:labelLeft, $y)
        # $lbl.Size = New-Object Drawing.Size(140, 30)
	$lbl.AutoSize = $true
        $lbl.Font = $global:FontRegular
        Set-LabelStyle -Label $lbl -Mode $currentMode
        $entryForm.Controls.Add($lbl)

        # TextBox
        $txt = New-Object Windows.Forms.TextBox
        $txt.Location = New-Object Drawing.Point($global:inputLeft, $y)
        $txt.Size = New-Object Drawing.Size($global:inputWidth, $global:inputHght)
        $txt.Font = $global:FontRegular
        Set-TextboxStyle -Textbox $txt -Mode $currentMode

        # Attach browse button ONLY for path fields
	    if ($labelText -like "Path to*") {

            $browseBtn = New-Object System.Windows.Forms.Button
            $browseBtn.Text = "Browse"
            $browseBtn.Size = New-Object System.Drawing.Size($global:buttonwidth, $global:buttonHght)
	    $browseBtn.Location = New-Object System.Drawing.Point($global:browseLeft, $y)
            $browseBtn.Font = $global:FontRegular
            Set-ButtonStyle -Button $browseBtn -Mode $currentMode
	    
            # Placeholder tag — checkbox will be filled in later
            $browseBtn.Tag = @{
                textbox  = $txt
                checkbox = $null
                # isFile   = ($labelText -eq "Path to custom file")
		        isFile = $labelText -in @("Path to custom file", "Path to Executable")
            }

            # Add click event
            $browseBtn.Add_Click({
                $btn  = $this
                $refs = $btn.Tag

                $txtRef = $refs.textbox
                $chkRef = $refs.checkbox

                if ($refs.isFile) {
                    # FILE picker
                    $dialog = New-Object System.Windows.Forms.OpenFileDialog
		    $dialog.InitialDirectory = Join-Path $rootDir "etc"
		    $dialog.Filter = "All Files (*.*)|*.*"
                    $result = $dialog.ShowDialog()
                    if ($result -eq [Windows.Forms.DialogResult]::OK) {
                        $path = $dialog.FileName
                    } else { return }
                }
                else {
                    # FOLDER picker
                    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
                    $result = $dialog.ShowDialog()
                    if ($result -eq [Windows.Forms.DialogResult]::OK) {
                        $path = $dialog.SelectedPath
                    } else { return }
                }

		# Apply portability replacemen
		
		$converted = Convert-ToTag -Path $path -CurDrv $curDrv -Tag '{DRIVE}'
		
		# Apply portability replacement $volLabel  only if checkbox is checked
		        # and the drive selected is the same as the drive where script is running
                # if ($chkRef -and $chkRef.Checked) {
                    # Replace drive letter with $volLabel 
                #    $drive = (Split-Path $path -Qualifier)
		#            if ($drive -ieq $env:curDrv) {
		#	            $path = $path.Replace($drive, "$volLabel")
		#            }     
                # }

                $txtRef.Text = $converted
            })

            $browseButtons += $browseBtn      # ← collect for later patching
            $entryForm.Controls.Add($browseBtn)
        }

        # Preload values
        if ($selectedItem -and $labels.IndexOf($labelText) -lt $selectedItem.SubItems.Count) {
            $txt.Text = $selectedItem.SubItems[$labels.IndexOf($labelText)].Text
        }
	if ($labelText-eq "ID" -and !$selectedItem) {
		$txt.Text = [Guid]::NewGuid().ToString()
		$txt.ReadOnly = $true
	    } elseif ($selectedItem -and $labels.IndexOf($labelText) -lt $selectedItem.SubItems.Count)
	    {
		$txt.Text = $selectedItem.SubItems[$labels.IndexOf($labelText)].Text
	    }

        $textboxes[$labelText] = $txt
        $entryForm.Controls.Add($txt)
        $y += 35
    }

    # Create checkbox NOW (after browse buttons exist)
    $checkbox = $null
    if ($global:mainMenu) {
        $checkbox = New-Object Windows.Forms.CheckBox
        $checkbox.Text = "$volLabel represents the current drive and should always be used for xampp installs on this drive"
        $checkbox.Location = New-Object Drawing.Point(10, $y)
        $checkbox.AutoSize = $true
        $checkbox.Checked = $true
	$checkbox.visible = $false
        Set-CheckboxStyle -Checkbox $checkbox -Mode $currentMode
        $entryForm.Controls.Add($checkbox)
        $y += 40
    }

    # 🔥 PATCH BROWSE BUTTON TAGS WITH LIVE CHECKBOX REFERENCE
    foreach ($btn in $browseButtons) {
        $btn.Tag.checkbox = $checkbox
    }

   # OK button
    $btnOK = New-Object Windows.Forms.Button
    $btnOK.Text = "OK"
    $btnOK.Font = $global:FontRegular
    $btnOK.Size = New-Object System.Drawing.Size($global:buttonwidth, $global:buttonHght)
    $btnOK.Location = New-Object Drawing.Point($global:inputLeft, $y)
    $btnOK.DialogResult = [Windows.Forms.DialogResult]::OK
    Set-ButtonStyle -Button $btnOK -Mode $currentMode
    $entryForm.AcceptButton = $btnOK
    $entryForm.Controls.Add($btnOK)

    # Cancel button
    $btnCancel = New-Object Windows.Forms.Button
    $btnCancel.Text = "Cancel"
    $btnCancel.Font = $global:FontRegular
    $btnCancel.Size = New-Object System.Drawing.Size($global:buttonwidth, $global:buttonHght)
    # $btnCancel.Location = New-Object Drawing.Point(250, $y)
    $btnCancel.Left = $global:inputLeft + $global:buttonwidth  + 200
    $btnCancel.Top = $y
    $btnCancel.DialogResult = [Windows.Forms.DialogResult]::Cancel
    Set-ButtonStyle -Button $btnCancel -Mode $currentMode
    $entryForm.CancelButton = $btnCancel
    $entryForm.Controls.Add($btnCancel)

    return @{Form=$entryForm; Textboxes=$textboxes; Checkbox=$checkbox}
}


function Validate-Form($textboxes) {
    if ($global:mainMenu) {
        $name  = $textboxes["Button"].Text.Trim()
        $id    = $textboxes["ID"].Text.Trim()
        $url   = $textboxes["URL"].Text.Trim()
        $path1 = $textboxes["Path to Xampp"].Text.Trim()
        $path2 = $textboxes["Path to custom file"].Text.Trim()

        # Validation
        if ($name -and $id -and ($url -or $path1 -or $path2)) {
            return @{
                IsValid = $true
                Name = $name
                ID = $id
                URL = $url
                Path1 = $path1
                Path2 = $path2
	        }
        } else {
            return @{
                IsValid = $false
                Message = "Please provide Name and ensure at least one of URL, Xampp Path, or Custom Path is filled."
            }
	    }
    } else {
        $name  = $textboxes["Button"].Text.Trim()
        $id    = $textboxes["ID"].Text.Trim()
        $path1 = $textboxes["Path to Executable"].Text.Trim()
        $path2 = $textboxes["URL"].Text.Trim()


	    # Validation
        if ($name -and $id -and ($path1 -or $path2)) {
            return @{
            IsValid = $true
            Name = $name
            ID = $id
            Path1 = $path1
            Path2 = $path2
            }
        } else {
            return @{
                IsValid = $false
                Message = "Please provide Name and ensure at least one Path or URL is filled."
            }
	    }
    }
}

# --------------------------------------
# Add-NewEntry
# --------------------------------------

function Add-NewEntry($textboxes, $checkbox) {

    $validation = Validate-Form $textboxes
  
    if ($validation.IsValid) {
	if ($global:mainMenu) {
	    
	    $name  = $validation.Name
	    $id    = $validation.ID
	    $url   = $validation.URL
	    $path1 = $validation.Path1
	    $path2 = $validation.Path2
	    
	    # Add the new path to the ComboBox if not already present
	#    if ($path2 -and -not $textboxes.Path2.Items.Contains($path2)) {
	#	$textboxes.Path2.Items.Add($path2)
	#    }
	    $entryLine = "$name|$id"
	    if ($url) { $entryLine += "|$url" }
	    if ($path1) { $entryLine += "|$path1" }
	    if ($path2) { $entryLine += "|$path2" }

	}else{

	    $name  = $validation.Name
	    $id    = $validation.ID
	    $path1 = $validation.Path1
	    $path2 = $validation.Path2

	    $entryLine = "$name|$id"
	    if ($path1) { $entryLine += "|$path1" }
	    if ($path2) { $entryLine += "|$path2" }
	}

        Add-Content -Path $global:filepath -Value $entryLine
        Load-Entries
    } else {
	Show-Alert -Message $validation.Message -Title "Missing Information"
    }
}
# --------------------------------------
# Edit-Entry
# --------------------------------------

function Edit-Entry($selectedItem, $textboxes, $checkbox) {
    $validation = Validate-Form $textboxes
    if ($validation.IsValid) {
	    if ($global:mainMenu) {
	        $name  = $validation.Name
	        $id    = $validation.ID
	        $url   = $validation.URL
	        $path1 = $validation.Path1
	        $path2 = $validation.Path2
	        $newLine = "$name|$id|$url|$path1"
	        if ($path2) { 
                $newLine += "|$path2" 
            }
            $lines = Get-Content $global:filepath
            $updatedLines = $lines | ForEach-Object {
                $fields = $_ -split '\|'
                if ($fields[1] -eq $selectedItem.SubItems[1].Text) {
                    $newLine
                } else {
                    $_
                }
            }
            $updatedLines | Set-Content $global:filepath
            Load-Entries

	    } else {
		$name  = $validation.Name
		$id    = $validation.ID
		$path1 = $validation.Path1
		$path2 = $validation.Path2

		$newLine = "$name|$id|$path1|$path2"

		$lines = Get-Content $global:filepath
		$updatedLines = $lines | ForEach-Object {
		    $fields = $_ -split '\|'
		    if ($fields[1] -eq $selectedItem.SubItems[1].Text) {
			$newLine
		    } else {
			$_
		    }
		}
		$updatedLines | Set-Content $global:filepath
		Load-Entries
	    }

    } else {
        [void][System.Windows.Forms.MessageBox]::Show(
            $validation.Message,
            "Missing Information",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
    }
}


# --------------------------------------
# Build-MainForm
# --------------------------------------

function Build-MainForm {
    $form.Controls.Clear()
    Set-FormTheme -Form $form -Mode $currentMode

    # --- Radio Buttons ---
    $global:radioMain = New-Object Windows.Forms.RadioButton
    $radioMain.Text = "Main"
    $radioMain.Left = 10
    $radioMain.Top = 10
    $radioMain.AutoSize = $true
    $radioMain.Checked = $global:mainMenu
    Set-RadioStyle -Radio $radioMain -Mode $currentMode
    $radioMain.Add_CheckedChanged({
        if ($radioMain.Checked) {
            $global:mainMenu = $true
            Build-MainForm
        }
    })
    $form.Controls.Add($radioMain)

    $global:radioUtil = New-Object Windows.Forms.RadioButton
    $radioUtil.Text = "Utility"
    $radioUtil.Left = 100
    $radioUtil.Top = 10
    $radioUtil.AutoSize = $true
    $radioUtil.Checked = -not $global:mainMenu
    Set-RadioStyle -Radio $radioUtil -Mode $currentMode
    $radioUtil.Add_CheckedChanged({
        if ($radioUtil.Checked) {
            $global:mainMenu = $false
            Build-MainForm
        }
    })
    $form.Controls.Add($radioUtil)

    # --- ListView ---
    $global:listView = New-Object Windows.Forms.ListView
    $listView.View = 'Details'
    $listView.FullRowSelect = $true
    $listView.MultiSelect = $false
    $listView.Size = '1000,300'
    $listView.Location = '10,40'
    $listView.Font = $global:FontRegular
    Set-ListViewStyle -ListView $listView -Mode $currentMode

    if ($global:mainMenu) {
        $global:filepath = Join-Path $rootDir "data\buttons.txt"
        $listView.Columns.Add("Button", 200) | Out-Null
        $listView.Columns.Add("ID", 50) | Out-Null
        $listView.Columns.Add("URL", 250) | Out-Null
        $listView.Columns.Add("Path to Xampp Directory", 250) | Out-Null
        $listView.Columns.Add("Path to custom script", 250) | Out-Null
    } else {
        $global:filepath = Join-Path $rootDir "data\buttons-util.txt"
        $listView.Columns.Add("Button", 200) | Out-Null
        $listView.Columns.Add("ID", 50) | Out-Null
        $listView.Columns.Add("Executable", 150) | Out-Null
        $listView.Columns.Add("URL", 150) | Out-Null
    }
    $form.Controls.Add($listView)

    # --- Buttons ---
    $btnWidth = $global:buttonwidth
    $btnHght = $global:buttonHght
   
    $btnSpace = 140
    $btnLeftStrt = 100
    $btnLeft = $btnLeftStrt

    $btnAdd = New-Object Windows.Forms.Button
    $btnAdd.Text = "Add Entry"
    $btnAdd.Size = New-Object System.Drawing.Size($btnWidth,$btnHght)
    $btnAdd.Location = New-Object System.Drawing.Point($btnLeft,360)
    $btnAdd.Font = $global:FontRegular
    Set-ButtonStyle -Button $btnAdd -Mode $currentMode
    $btnAdd.Add_Click({
        $entryFormData = Create-EntryForm "Add New Entry"

	if ($global:mainMenu) {
	    $global:filepath = Join-Path $rootDir "data\buttons.txt"
	}else{
	    $global:filepath = Join-Path $rootDir "data\buttons-util.txt"
	}

        if ($entryFormData.Form.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
	   Add-NewEntry $entryFormData.Textboxes $entryFormData.checkbox
        }
    })
    $form.Controls.Add($btnAdd)

    $btnLeft = (1*$btnSpace) + $btnLeftStrt

    $btnDelete = New-Object Windows.Forms.Button
    $btnDelete.Text = "Delete Entry"
    $btnDelete.Size =  New-Object System.Drawing.Size($btnWidth,$btnHght)
    $btnDelete.Location = New-Object System.Drawing.Point($btnLeft,360)
    $btnDelete.Font = $global:FontRegular
    Set-ButtonStyle -Button $btnDelete -Mode $currentMode
    $btnDelete.Add_Click({
	if ($global:mainMenu) {
	    $global:filepath = Join-Path $rootDir "data\buttons.txt"
	}else{
	    $global:filepath = Join-Path $rootDir "data\buttons-util.txt"
	}
        if ($listView.SelectedItems.Count -gt 0) {
            $selectedID = $listView.SelectedItems[0].SubItems[1].Text
            $lines = Get-Content $global:filepath
            $filteredLines = $lines | Where-Object {
                ($_ -split '\|')[1] -ne $selectedID
            }
            $filteredLines | Set-Content $global:filepath
            Load-Entries
        }
    })
    $form.Controls.Add($btnDelete)

      $btnLeft = (2*$btnSpace) + $btnLeftStrt

    $btnEdit = New-Object Windows.Forms.Button
    $btnEdit.Text = "Edit Entry"
    $btnEdit.Size =  New-Object System.Drawing.Size($btnWidth,$btnHght)
    $btnEdit.Location = New-Object System.Drawing.Point($btnLeft,360)
    $btnEdit.Font = $global:FontRegular
    Set-ButtonStyle -Button $btnEdit -Mode $currentMode

    $btnEdit.Add_Click({
	if ($listView.SelectedItems.Count -eq 0) {
	    [void][System.Windows.Forms.MessageBox]::Show(
		"Please select an entry to edit.",
		"No Selection",
		[System.Windows.Forms.MessageBoxButtons]::OK,
		[System.Windows.Forms.MessageBoxIcon]::Information
	    )
	    return
	}

	$selectedItem = $listView.SelectedItems[0]

	$entryFormData = Create-EntryForm "Edit Entry" $selectedItem

	if ($entryFormData.Form.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
	    # Only update the file if OK is pressed
	    Edit-Entry $selectedItem $entryFormData.Textboxes $entryFormData.Checkbox
	}
    })

    $form.Controls.Add($btnEdit)

      $btnLeft = (3*$btnSpace) + $btnLeftStrt

    $btnReorder = New-Object Windows.Forms.Button
    $btnReorder.Text = "Reorder"
    $btnReorder.Size =  New-Object System.Drawing.Size($btnWidth,$btnHght)
    $btnReorder.Location = New-Object System.Drawing.Point($btnLeft,360)
    $btnReorder.Font = $global:FontRegular
    Set-ButtonStyle -Button $btnReorder -Mode $currentMode

    $btnReorder.Add_Click({

	# Pass the current file being edited to the reorder window
	Show-ReorderWindow -FilePath $global:filepath

	# Reload list after reordering
	Load-Entries
    })

    $form.Controls.Add($btnReorder)

    $btnLeft = (5*$btnSpace) + $btnLeftStrt

    $btnOk = New-Object Windows.Forms.Button
    $btnOk.Text = "Ok"
    $btnOk.Size =  New-Object System.Drawing.Size($btnWidth,$btnHght)
    $btnOk.Location = New-Object System.Drawing.Point($btnLeft,360)
    $btnOk.Font = $global:FontRegular
    Set-ButtonStyle -Button $btnOk -Mode $currentMode

    $btnOk.Add_Click({



	 $form.Close()
    })

    $form.Controls.Add($btnOk)


    # --- Load Entries ---
    Load-Entries
}

# Load entries
function Load-Entries {
    if ($global:mainMenu) {
        $global:filePath = Join-Path $rootDir "data\buttons.txt"
    } else {
        $global:filePath = Join-Path $rootDir "data\buttons-util.txt"
    }
    $listView.Items.Clear()
    if (Test-Path $global:filepath) {
        Get-Content $global:filepath | ForEach-Object {
            if ($_ -match "\S") {
                $fields = $_ -split '\|'
                $item = New-Object Windows.Forms.ListViewItem($fields[0])
                for ($i = 1; $i -lt $fields.Count; $i++) {
                    [void]$item.SubItems.Add($fields[$i])
                }
                [void]$listView.Items.Add($item)
            }
        }
    }
}

# ------------------------------------------------
#
# MENU Maintenance 
#
#-------------------------------------------------

Import-Module (Join-Path $rootDir "etc\includes\UIHelpers.psm1") -Force
Import-Module (Join-Path $rootDir "etc\includes\alert.psm1") -Force
Import-Module (Join-Path $rootDir "etc\includes\reorder.psm1") -Force

 if ($global:mainMenu) {
    $global:filepath = Join-Path $rootDir "data\buttons.txt"
} else {
    $global:filepath = Join-Path $rootDir "data\buttons-util.txt"
}

# Load theme and initialize

$themeFile = Join-Path $rootDir "data\theme.txt"
$currentMode = Import-ThemeState -themeFile $themeFile
$volLabel = "{DRIVE}"


$global:form = New-Object Windows.Forms.Form
$global:form.Font = $global:FontRegular
$global:form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Font
$global:form.Text = "xmenu Menu Maintenance"
$global:form.Size = '1050, 500'
$global:form.StartPosition = 'CenterScreen'


$global:mainMenu = $true  # or load from preference

# Initial form build
Build-MainForm
# Show the form
[void]$form.ShowDialog()















