param (
        [string]$sitePath  # Expecting an array of file paths (strings)
    )

$duplicatorBackups = "$sitePath\wp-content\duplicator-backups\installer\"
# get newest installer log
$logFile = Get-ChildItem "$duplicatorBackups\dup-installer-log*.txt" -ErrorAction SilentlyContinue |
           Sort-Object LastWriteTime -Descending |
           Select-Object -First 1

if (-not $logFile) {
    Write-Output "NOT_FOUND"
    Write-Output ""
    return
}

$content = Get-Content $logFile.FullName

# extract archive path
$archivePath = ($content | Select-String 'ARCHIVE NAME.*"([^"]+)"').Matches.Groups[1].Value

if (-not $archivePath) {
    Write-Output "NOT_FOUND"
    Write-Output ""
    return
}

$archiveFile = [System.IO.Path]::GetFileName($archivePath)

if ($archiveFile -match '^(\d{8})_([^_]+)_\[([^\]]+)\]_(\d{14})_archive\.daf$') {
    $timestamp = $matches[4]
} else {
    Write-Output "NOT_FOUND"
    Write-Output ""
    return
}

try {
    $archiveDate = [datetime]::ParseExact($timestamp,'yyyyMMddHHmmss',$null)
} catch {
    Write-Output "NOT_FOUND"
    Write-Output ""
    return
}

#ONLY OUTPUT RAW VALUES
Write-Output $archiveFile
Write-Output $archiveDate.ToString("yyyy-MM-dd HH:mm:ss")
