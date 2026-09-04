$proc = Get-Process | Where-Object { $_.Path -match 'httpd.exe' } -ErrorAction SilentlyContinue

if ($null -eq $proc) {
    Write-Output "Status=Stopped"
    Write-Output "ExePath="
    Write-Output "Htdocs="
    exit
}

# Apache is running
$exePath = ($proc | Select-Object -First 1).Path
# normalize to a back slash
$ExePath = $ExePath -replace '/', '\'

Write-Output "Status=Running"
Write-Output "ExePath=$exePath"

# Find httpd.conf near the executable
$binDir     = Split-Path $exePath -Parent
$apacheRoot = Split-Path $binDir -Parent
$confPath   = Join-Path $apacheRoot "conf\httpd.conf"

if (Test-Path $confPath) {
    $docRootLine = Select-String -Path $confPath -Pattern 'DocumentRoot' | 
        Where-Object { $_.Line -notmatch '^#' } | 
	Select-Object -First 1

    if ($docRootLine) {
	if ($docRootLine -match 'DocumentRoot\s+"([^"]+)"') {
	    $documentRoot = $matches[1]
	    $documentRoot = $documentRoot -replace '/', '\' # normailize to back slash
	}   
	
	Write-Output "Htdocs=$documentRoot"
       
    } else {
        Write-Output "Htdocs=NotFound"
    }
} else {
    Write-Output "Htdocs=NotFound"
}
