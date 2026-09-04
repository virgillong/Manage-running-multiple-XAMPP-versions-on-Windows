param (
    [string]$xamppDir
)

function Test-IsAdmin {
    $currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Set-XamppAutostart {
    try {

        $iniPath = Join-Path -Path $xamppDir -ChildPath "xampp-control.ini"
        Write-Host
	Write-Host "Editing: $iniPath to enable auto start capabilites for apache webserver and mysql"

        

        # Try to read the file first (this is where access denied will hit)
        $content = Get-Content -Path $iniPath -ErrorAction Stop

        # Your original logic here...
        $desiredSettings = @{
            Apache    = "1"
            MySQL     = "1"
            FileZilla = "0"
            Mercury   = "0"
            Tomcat    = "0"
        }

        $inAutostart = $false
        $settingsFound = @{}
        $updatedContent = @()
        $changesNeeded = $false

        foreach ($line in $content) {
            if ($line -match '^\[Autostart\]') {
                $inAutostart = $true
                $updatedContent += $line
                continue
            }

            if ($inAutostart -and $line -match '^\[.*\]') {
                $inAutostart = $false
                foreach ($key in $desiredSettings.Keys) {
                    if (-not $settingsFound.ContainsKey($key)) {
                        $updatedContent += "$key=$($desiredSettings[$key])"
                        $changesNeeded = $true
                    }
                }
                $updatedContent += $line
                continue
            }

            if ($inAutostart) {
                $matched = $false
                foreach ($key in $desiredSettings.Keys) {
                    if ($line -match "^$key\s*=") {
                        $currentValue = $line.Split("=")[1].Trim()
                        if ($currentValue -ne $desiredSettings[$key]) {
                            $updatedContent += "$key=$($desiredSettings[$key])"
                            $changesNeeded = $true
                        } else {
                            $updatedContent += $line
                        }
                        $settingsFound[$key] = $true
                        $matched = $true
                        break
                    }
                }
                if (-not $matched) {
                    $updatedContent += $line
                }
            } else {
                $updatedContent += $line
            }
        }

        if (-not ($content -match '^\[Autostart\]')) {
            $updatedContent += "[Autostart]"
            foreach ($key in $desiredSettings.Keys) {
                $updatedContent += "$key=$($desiredSettings[$key])"
            }
            $changesNeeded = $true
        }

        if ($changesNeeded) {
            Set-Content -Path $iniPath -Value $updatedContent -Encoding ASCII
            Write-Host " xampp-control.ini updated."
        } else {
            Write-Host "No changes needed."
        }
    } catch {
        if ($_ -match "Access to the path .* is denied") {
            if (-not (Test-IsAdmin)) {
                Write-Warning "Access denied. Trying to relaunch with administrator privileges..."
                Start-Process -FilePath "powershell" -Verb RunAs -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"", "-xamppDir", "`"$xamppDir`""
                exit
            } else {
                throw "Even as administrator, access was denied. Aborting."
            }
        } else {
            throw $_
        }
    }
}

try {
    Set-XamppAutostart
    exit 0  # success
} catch {
    Write-Error $_
    exit 1  # failure
}
