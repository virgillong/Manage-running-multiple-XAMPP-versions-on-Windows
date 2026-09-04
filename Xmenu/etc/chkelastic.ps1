
# Do not globally silence errors while debugging
# $ErrorActionPreference = 'SilentlyContinue'
$ErrorActionPreference = "Continue"

# Default path fallback for rootDir
if (-not $env:rootDir) {
    $env:rootDir = (Resolve-Path "$PSScriptRoot\..").Path
}
$rootDir = $env:rootDir 

if (-not $env:curDrv) {
    $env:curDrv = (Resolve-Path "$PSScriptRoot\..\..").Path
}
$curDrv = $env:curDrv

$filepath = Join-Path $rootDir 'Utilities\elasticsearch\bin\elasticsearch.bat'
$url      = 'http://localhost:9200'
$exitCode = 0

function Get-ElasticStatusCode {
    param (
        [string]$Uri
    )

    try {
        $response = Invoke-WebRequest -Uri $Uri -UseBasicParsing -Method Get -TimeoutSec 5
        return [string]$response.StatusCode
    }
    catch {
        if ($_.Exception.Response) {
            return [string]$_.Exception.Response.StatusCode.value__
        }

        return '000'
    }
}

# Check current Elasticsearch status
$httpCode = Get-ElasticStatusCode -Uri $url

if ($httpCode -eq '200') {

    Write-Host ""
    Write-Host "Elasticsearch is running."

}
else {

    Write-Host ""
    Write-Host "INFO: Starting Elasticsearch."
    Write-Host ""

    Start-Process -WindowStyle Minimized -FilePath $filepath

    $repeatCnt = 20
    $count     = 0

    while ($count -lt $repeatCnt) {

        Start-Sleep -Seconds 2

        $httpCode = Get-ElasticStatusCode -Uri $url

        if ($httpCode -eq '200') {

            $timerCount = $count * 2

            Write-Host "SUCCESS: Elasticsearch started."
            break
        }

        $count++

        if ($count -ge $repeatCnt) {

            $exitCode = 1
            $message  = 'Elasticsearch did not start on port 9200'

            Write-Host $message

            break
        }

        Write-Host "$count`: Waiting for Elasticsearch to start..."
    }
}

$global:message  = $message
$global:exitCode = $exitCode

return