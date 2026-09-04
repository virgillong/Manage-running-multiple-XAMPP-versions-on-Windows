function Show-VariableInfo {
    param (
        [Parameter(Mandatory)]
        $Variable
    )

    Write-Host "=== Variable Info ===" -ForegroundColor Cyan

    $type = $Variable.GetType().FullName
    Write-Host "Type      : $type"

    if ($Variable -is [System.Collections.IEnumerable] -and -not ($Variable -is [string])) {
        $count = $Variable.Count
        Write-Host "Count     : $count"
        Write-Host "Contents  :"
        $index = 0
        foreach ($item in $Variable) {
            Write-Host "[$index] $item"
            $index++
        }
    } else {
        Write-Host "Value     : $Variable"
    }

    Write-Host "=====================" -ForegroundColor Cyan
}