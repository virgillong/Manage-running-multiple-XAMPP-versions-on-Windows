# Function to compare installer.php archive filename with actual archive file
# Function to compare installer.php archive filename with actual archive file
function Compare-ArchiveFiles {
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$files  # Expecting an array of file paths (strings)
    )
    $msg = $null
    # Identify the installer.php file and the archive file (either .daf or .zip)
    $installer = $files | Where-Object { [System.IO.Path]::GetFileName($_) -ieq "installer.php" }
    $archive   = $files | Where-Object { $_ -match '\.(daf|zip)$' }

    # Ensure we have both files
    if (-not $installer) {
        $msg = "Missing 'installer.php'."
        return @($false, $msg)
    }

    if (-not $archive) {
        $msg = "Missing backup archive (.daf or .zip)."
        return @($false, $msg)
    }

    # Read the content of installer.php
    $installerFileContent = Get-Content $installer

    # Correct regex pattern to escape single quotes properly
    $archivePattern = "const\s+ARCHIVE_FILENAME\s+=\s+'([^\']+)'"

    $matches = [regex]::Match($installerFileContent, $archivePattern)

    if ($matches.Success) {
        $expectedArchiveFileName = $matches.Groups[1].Value
        # Write-Host "Expected Archive Filename: $expectedArchiveFileName"

        # Extract the actual archive filename (without directory path)
        $actualArchiveFileName = [System.IO.Path]::GetFileName($archive)

        # Compare the filenames
        if ($expectedArchiveFileName -ieq $actualArchiveFileName) {
           # Write-Host "The archive file matches the expected filename."
            return @($true,$msg)
        } else {
            $msg =  "The archive file does NOT match the expected filename.  "
            $msg += "Expected: $expectedArchiveFileName.  "
	    $msg += "Found: $actualArchiveFileName."
            
            return @($false, $msg)
        }
    } else {
	$msg = "Could not find the archive filename in installer.php"
        return @($false, $msg)
    }
}
