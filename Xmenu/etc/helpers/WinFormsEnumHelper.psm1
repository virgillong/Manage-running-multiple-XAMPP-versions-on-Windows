function Show-DialogEnumCheatSheet {
    $sections = @(
        @{
            Title = "DialogResult"
            Values = [System.Windows.Forms.DialogResult] | Enum::GetNames
        },
        @{
            Title = "MessageBoxButtons"
            Values = [System.Windows.Forms.MessageBoxButtons] | Enum::GetNames
        },
        @{
            Title = "MessageBoxIcon"
            Values = [System.Windows.Forms.MessageBoxIcon] | Enum::GetNames
        },
        @{
            Title = "FormStartPosition"
            Values = [System.Windows.Forms.FormStartPosition] | Enum::GetNames
        },
        @{
            Title = "FormBorderStyle"
            Values = [System.Windows.Forms.FormBorderStyle] | Enum::GetNames
        }
    )

    foreach ($section in $sections) {
        Write-Host "`n--- $($section.Title) ---" -ForegroundColor Cyan
        $section.Values | ForEach-Object {
            Write-Host "  $_"
        }
    }
}

Export-ModuleMember -Function Show-DialogEnumCheatSheet

