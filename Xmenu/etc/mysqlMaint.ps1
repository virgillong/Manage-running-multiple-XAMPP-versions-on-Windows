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

$xamppDirCur = $env:xamppDirCur
$xamppVersion = $env:xamppVersion


Import-Module (Join-Path $rootDir "etc\includes\UIHelpers.psm1") -Force
Import-Module (Join-Path $rootDir "etc\includes\alert.psm1") -Force
Import-Module (Join-Path $rootDir "etc\includes\addinputrow.psm1") -Force

$themeFile = Join-Path $rootDir "data\theme.txt"
$currentMode = Import-ThemeState -themeFile $themeFile


$defaultHost = "localhost"
$defaultUser = "root"
$defaultPWD = " "

if (-not (Get-NetTCPConnection -LocalPort 3306 -State Listen -ErrorAction SilentlyContinue)) {
    Show-Alert -Message "Did not find active MySQL, please start Xampp service from main menu"
    exit 1
}


function Get-MySqlDatabases {
    param (
        [string]$mysqlPath,
        [string]$dbUser,
        [string]$dbHost
    )

    $result = & "$mysqlPath" -u $dbUser -h $dbHost -e "SHOW DATABASES;" 2>$null

    if ($LASTEXITCODE -ne 0) {
        return @()
    }

    return $result |
        Select-Object -Skip 1 |
        Where-Object { $_ -ne "information_schema" -and $_ -ne "performance_schema" }
}
function Show-Result {
    param (
        [string]$SuccessMessage,
        [string]$FailureMessage,
        [int]$ExitCode
    )

    if ($ExitCode -eq 0) {
        Show-Alert -Message $SuccessMessage
    } else {
        Show-Alert -Message $FailureMessage
    }
}


# Load file
$filePath = Join-Path $rootDir "data\buttons.txt"
$entries = @()

# $fields[3] is the path to xampp folder, the drive may be
# literal a-z or portable {DRIVE}, the latter needs to be
# converted to the current drive

if (Test-Path $filePath) {
    $entries = Get-Content $filePath | ForEach-Object {
        $fields = $_ -split '\|'
        if ($fields.Count -ge 4) {
	    if ($fields[3] -match '^[A-Za-z]:\\') {
		# literal path, no replacement
		$expanded = $fields[3] 
	    } else {
		$expanded = $fields[3] -replace '{DRIVE}', $curDrv
	    }
	    $expanded
        }
    } | ForEach-Object { $_.ToLower() } | Select-Object -Unique | ForEach-Object { $_.ToUpper() }
}

# Create the form
$form = New-Object System.Windows.Forms.Form
$form.Font = $global:FontRegular
$form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Font
$form.Text = "Database Management" 
$form.Size = New-Object System.Drawing.Size($global:formWidth,420)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = 'Sizable'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.KeyPreview = $true   # Allows Enter/Esc handling
Set-FormTheme -Form $form -Mode $currentMode


# Create a label to display the current directory
$dirLabel = New-Object System.Windows.Forms.Label
$dirLabel.Text = "Current Directory: $xamppDirCur"
$dirLabel.Location = New-Object System.Drawing.Point(300, 10)
$dirLabel.Font = New-Object System.Drawing.Font('Arial', 10)
$dirLabel.ForeColor = [System.Drawing.Color]::Black
$dirLabel.AutoSize = $true
Set-LabelStyle -Label $dirLabel -Mode $currentMode
$form.Controls.Add($dirLabel)

# Create and add a label for displaying the PHP version
$phpVersionLabel = New-Object System.Windows.Forms.Label
$phpVersionLabel.Text = "PHP Version: $xamppVersion"
$phpVersionLabel.Location = New-Object System.Drawing.Point(300, 30)
$phpVersionLabel.Font = New-Object System.Drawing.Font('Arial', 10)
$phpVersionLabel.ForeColor = [System.Drawing.Color]::Black
$phpVersionLabel.AutoSize = $true
Set-LabelStyle -Label $phpVersionLabel -Mode $currentMode
$form.Controls.Add($phpVersionLabel)

$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Location = New-Object System.Drawing.Point(50, 330)
$progress.Size = New-Object System.Drawing.Size(300, 20)
$progress.Style = 'Marquee'     # <-- key
$progress.Visible = $false
$form.Controls.Add($progress)


$topStrt = 80
$spacing = 40

$XamppFolder, $label = Add-InputRow $form "XAMPP Folder:" $topStrt "textbox"
$XamppFolder.text = $xamppDirCur
$XamppFolder.ReadOnly = $true
$XamppFolder.BorderStyle = 'None'
 

$top = (1*$spacing) + $topstrt
$MysqlAction, $label = Add-InputRow $form "Mysql Action:" $top "combobox"
$MysqlAction.Items.AddRange(@("List", "Create", "Delete", "Load", "Dump"))
$MysqlAction.SelectedIndex = 0
$form.Add_Shown({
    $MysqlAction.Focus()
})

$top = (2*$spacing) + $topstrt
$HostURL, $label = Add-InputRow $form "Host:" $top "textbox"
$HostURL.text = $defaultHost

$top = (3*$spacing) + $topstrt
$User, $label = Add-InputRow $form "User:" $top "textbox"
$User.text = $defaultUser
$User.ReadOnly = $true

# $top = (4*$spacing) + $topstrt
# $Password, $label = Add-InputRow $form "Password:" 190 "textbox"
# $Password.text = $defaultPWD
# $top = (5*$spacing) + $topstrt

$top = (4*$spacing) + $topstrt
$DBname, $labelDBname = Add-InputRow $form "DB Name:" $top "textbox"

# $top = (5*$spacing) + $topstrt
# one of the next two items will appear in place of $DBname
# if "list" then DBListTxt will appear to display all databases
# if "Delete" then DBList appears to allow chosing database
# if "Create" then $DBname appears and the two above disappear
$topDBList = $top
$DBList, $LabelDBList = Add-InputRow $form "Databases:" $top "combobox"
$DBList.Enabled = $false
$DBList.Add_SelectedIndexChanged({
    if ($MysqlAction.SelectedItem -eq "Delete" -and $DBList.SelectedItem) {
        $DBname.Text = $DBList.SelectedItem
    }
 })
$DBListTxt, $LabelDBListTxt = Add-InputRow $form "Databases:" $top "textbox"
$DBListTxt.Multiline = $true
$DBListTxt.Height = 60


$top = (5*$spacing) + $topstrt
# appears when the action is "load" or "dump"
$DBFile, $LabelDBFile = Add-InputRow $form "DB File (sql):" $top "textbox"

$browseButton,$label = Add-InputRow $form "" $top "browse"
$browseButton.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.InitialDirectory = Join-Path $rootDir "data"
    $dlg.Filter = "SQL files (*.sql)|*.sql|All files (*.*)|*.*"

    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $DBFile.Text = $dlg.FileName
    }
}.GetNewClosure())


$top = (6*$spacing) + $topstrt
# OK Button
$okButton = New-Object System.Windows.Forms.Button
$okButton.Text = "OK"
$okButton.Location = New-Object System.Drawing.Point(200,$top)
$form.Controls.Add($okButton)

# Cancel Button
$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Text = "Cancel"
$cancelButton.Location = New-Object System.Drawing.Point(290,$top)
$cancelButton.Add_Click({ $form.Close() })
$form.Controls.Add($cancelButton)

$buttons = @($okButton, $cancelButton)
foreach ($btn in $buttons) {
    Set-ButtonStyle -Button $btn -Mode $currentMode
    [void]$form.Controls.Add($btn)
}


# set LIST controls by default
$DBList.visible = $LabelDBList.visible = $false
$DBname.Visible = $labelDBname.Visible  = $false
$DBFile.Visible = $LabelDBFile.Visible = $browseButton.visible = $false

$mysqlPath = Join-Path $XamppFolder.Text "mysql\bin\mysql.exe"
$dbs = Get-MySqlDatabases `
    -mysqlPath $mysqlPath `
    -dbUser $User.Text `
    -dbHost $HostURL.Text

if ($dbs.Count -gt 0) {
    $DBListTxt.text =$dbs
}
# *************************************
#		Events
# *************************************


# **************************
# MysqlAction change event
# **************************
$MysqlAction.Add_SelectedIndexChanged({

    $mysqlPath = Join-Path $XamppFolder.Text "mysql\bin\mysql.exe"

    switch ($MysqlAction.SelectedItem) {

        "Create" {
            $DBList.Enabled = $false
            $DBList.Items.Clear()
	    $DBname.text=""

	    $DBList.Visible = $LabelDBList.Visible = $false
	    $DBListTxt.Visible = $LabelDBListTxt.Visible = $false
	    $DBname.Visible = $labelDBname.Visible = $true
	    $DBFile.Visible = $LabelDBFile.Visible = $browseButton.visible = $false
        }

        "Delete" {
	    $DBList.Enabled = $true
	    $DBList.Items.Clear()
	   
	    $DBList.Visible = $LabelDBList.Visible = $true
	    $DBListTxt.Visible = $LabelDBListTxt.Visible = $false
	    $DBname.Visible = $labelDBname.Visible = $false
	    $DBFile.Visible = $LabelDBFile.Visible = $browseButton.visible = $false
	    $dbs = Get-MySqlDatabases `
		-mysqlPath $mysqlPath `
		-dbUser $defaultUser `
		-dbHost $HostURL.Text

	    # 🔒 FILTER SYSTEM DATABASES HERE
	    $dbs = $dbs | Where-Object {
		$_ -notin @(
		    'information_schema',
		    'mysql',
		    'performance_schema',
		    'sys',
		    'phpmyadmin'
		)
	    }

	    if ($dbs.Count -gt 0) {
		$DBList.Items.AddRange($dbs)
		# $DBList.SelectedIndex = 0
		$DBname.Text = $DBList.SelectedItem
	    }
	    else {
		[System.Windows.Forms.MessageBox]::Show(
		    "No user databases found."
		)
	    }
	}

        "List" {
            $DBList.Enabled = $true
            $DBList.Items.Clear()
	    
	    $DBList.Visible = $LabelDBList.Visible = $false
	    $DBListTxt.Visible = $LabelDBListTxt.Visible = $true
	    $DBname.Visible = $labelDBname.Visible = $false
	    $DBFile.Visible = $LabelDBFile.Visible = $browseButton.visible = $false

	    $dbs = Get-MySqlDatabases `
                -mysqlPath $mysqlPath `
                -dbUser $defaultUser `
                -dbHost $HostURL.Text

            if ($dbs.Count -gt 0) {
                # $DBList.Items.AddRange($dbs)
		$DBList.text = $dbs
            }
        }

	"Load" {
	    $DBList.Enabled = $true
	    $DBList.Items.Clear()
	    $DBFile.Text = " "

	    $DBList.Visible = $LabelDBList.Visible = $true
	    $DBListTxt.Visible = $LabelDBListTxt.Visible = $false
	    $DBname.Visible = $labelDBname.Visible = $false
            $DBFile.Visible = $LabelDBFile.Visible = $browseButton.visible = $true
	    
	    $dbs = Get-MySqlDatabases `
		-mysqlPath $mysqlPath `
		-dbUser $defaultUser `
		-dbHost $HostURL.Text

	    # 🔒 FILTER SYSTEM DATABASES HERE
	    $dbs = $dbs | Where-Object {
		$_ -notin @(
		    'information_schema',
		    'mysql',
		    'performance_schema',
		    'sys',
		    'phpmyadmin'
		)
	    }

	    if ($dbs.Count -gt 0) {
		$DBList.Items.AddRange($dbs)
		$DBList.SelectedIndex = 0
		$DBname.Text = $DBList.SelectedItem
	    }
	    else {
		[System.Windows.Forms.MessageBox]::Show(
		    "No user databases found."
		)
	    }    
	}
	"Dump" {
	    $DBList.Enabled = $true
	    $DBList.Items.Clear()

	    $DBList.Visible = $LabelDBList.Visible = $true
	    $DBListTxt.Visible = $LabelDBListTxt.Visible = $false
	    $DBname.Visible = $labelDBname.Visible = $false
            $DBFile.Visible = $LabelDBFile.Visible = $browseButton.visible = $true
	    
	    $dbs = Get-MySqlDatabases `
		-mysqlPath $mysqlPath `
		-dbUser $defaultUser `
		-dbHost $HostURL.Text

	    # 🔒 FILTER SYSTEM DATABASES HERE
	    $dbs = $dbs | Where-Object {
		$_ -notin @(
		    'information_schema',
		    'mysql',
		    'performance_schema',
		    'sys',
		    'phpmyadmin'
		)
	    }

	    if ($dbs.Count -gt 0) {
		$DBList.Items.AddRange($dbs)
		$DBList.SelectedIndex = 0
		$DBname.Text = $DBList.SelectedItem
	    }
	    else {
		[System.Windows.Forms.MessageBox]::Show(
		    "No user databases found."
		)
	    }
	}
    }
})

# ***********************
# DBList change event
# ***********************

$DBList.Add_SelectedIndexChanged({
    if ($MysqlAction.SelectedItem -eq "Dump") {
	$DBFile.Text = Join-Path $rootDir "data\$($DBList.SelectedItem).sql"
    }
})

# **************************
# ok BUTTON event
# **************************

$global:selectedItem = $null
$okButton.Add_Click({
    $global:selectedItem = $true

     function Test-RequiredFields {
        param ([System.Windows.Forms.TextBox[]]$TextBoxes)
        foreach ($tb in $TextBoxes) {
            if ([string]::IsNullOrWhiteSpace($tb.Text)) {
		Show-Alert -Message "One or more required fields are empty"
                return $false
            }
        }
        return $true
    }

    if (-not (Test-RequiredFields @($HostURL, $User))) {
        return
    }
    
    switch ($MysqlAction.SelectedItem) {
	"List" {
	}
	"Create" {
	    if ([string]::IsNullOrWhiteSpace($DBname.Text)) {

		Show-Alert -Message "Database Name is a required field"
                return
            }
	}
	"Delete" {
	    if (-not $DBList.SelectedItem) {
		Show-Alert -Message "Please choose a database from the list"
                return
            }
	}
	"Load" {
	    if ([string]::IsNullOrWhiteSpace($DBfile.Text)) {
		Show-Alert -Message "Please enter a file to load"
                return
            }
            if (-not $DBList.SelectedItem) {
		Show-Alert -Message "Please choose a database from the list"
                return
            }
	}

	"Dump" {
	    if ([string]::IsNullOrWhiteSpace($DBfile.Text)) {
		Show-Alert -Message "Please enter the path to a file to dump contents of database"
                return
            }
            if (-not $DBList.SelectedItem) {
                Write-Host "Please choose a database"
                return
            }
	}
    }

    $form.Close()
})

# **************************
# Cancel button event
# **************************

$cancelButton.Add_Click({
    $global:selectedItem = $false
    $form.Close()
})

# --- Keyboard shortcuts ---
$form.Add_KeyDown({
    param($sender, $e)

    switch ($e.KeyCode) {

        'Enter' {$okButton.PerformClick()}

        'Escape' {$cancelButton.PerformClick()}
    }
})

# **************************
# Show Form
# **************************

$form.Topmost = $true
$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()

# Flag used to exit (cancel)

if (-not($global:selectedItem)) {
    exit 1
} 

$dbHost = $HostURL.text
$dbUser = $User.text
$dbPass = $Password.text
$dbFile = $DBFile.Text
$mysqlPath     = Join-Path $XamppFolder.Text "mysql\bin\mysql.exe"
$mysqlDumpPath = Join-Path $XamppFolder.Text "mysql\bin\mysqldump.exe"
# $errFile = "$dbFile.err

$errorfn = [System.IO.Path]::GetFileName($dbFile) + ".err"
$errFile = Join-Path $rootDir "data\logs\$errorfn"

switch ($MysqlAction.SelectedItem) {

    "Create" {
	$dbName = [string]($DBname.Text).Trim()
        & $mysqlPath -u root -e "CREATE DATABASE IF NOT EXISTS $dbName;"
	Show-Result `
	    -SuccessMessage "Database created successfully" `
	    -FailureMessage "Failed to create database" `
	    -ExitCode $proc.ExitCode
    }

    "Delete" {
	$dbName = $DBList.SelectedItem.ToString().Trim()
        & $mysqlPath -u root -e "DROP DATABASE IF EXISTS $dbName;"
	Show-Result `
	    -SuccessMessage "Database deleted successfully" `
	    -FailureMessage "Failed to delete database" `
	    -ExitCode $proc.ExitCode
    }

    "List" {
        & $mysqlPath -u root -e "SHOW DATABASES;"
    }

    "Load" {
	    $dbName = $DBList.SelectedItem.ToString().Trim()
	    # Ensure the SQL file exists
	    if (-not (Test-Path $dbFile)) {
		Write-Host "SQL file not found: $dbFile"
		return
	    }
	    $outFile = Join-Path $env:TEMP ("mysql_" + [guid]::NewGuid() + ".out")
	    # Run mysql to load the SQL file
	    Write-Host ".... Importing $dbFile to database $dbName"
	    $proc = Start-Process `
		-FilePath $mysqlPath `
		-ArgumentList "-u root", $dbName `
		-RedirectStandardInput $dbFile `
		-RedirectStandardOutput $outFile `
		-RedirectStandardError $errFile `
		-NoNewWindow `
		-Wait `
		-PassThru

	    $stdout = Get-Content $outFile -Raw
	    $stderr = Get-Content $errFile -Raw

	    if ($proc.ExitCode -ne 0 -or $stderr -match 'ERROR') {
		Show-Alert -Message "Database load failed:`n$stderr"
	    }
	    elseif ($stdout -match 'Warning|WARNING') {
		Show-Alert -Message "Database loaded with warnings:`n$stdout"
	    }
	    else {
		Show-Alert -Message "Database loaded successfully"
	    }
	}


    "Dump" {
	$dbName = $DBList.SelectedItem.ToString().Trim()
	Write-Host ".... Exporting database $dbName to $dbFile"
	$proc = Start-Process `
	    -FilePath $mysqlDumpPath `
	    -ArgumentList "-u root", $dbName `
	    -RedirectStandardOutput $dbFile `
	    -RedirectStandardError $errFile `
	    -NoNewWindow `
	    -Wait `
	    -PassThru

	if (Test-Path $errFile) {
	    $stderr = Get-Content $errFile -Raw
	}
	

	if ($proc.ExitCode -ne 0 -or $stderr -match 'ERROR') {
	    Show-Alert -Message "Database dump failed:`n$stderr"
	}
	elseif ($stderr -match 'Warning|WARNING') {
	    Show-Alert -Message "Database dumped with warnings:`n$stderr"
	}
	else {
	    Show-Alert -Message "Database dumped successfully"
	}
    }
}

  



