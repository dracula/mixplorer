#!/usr/bin/pwsh -c
param ([Alias('p')][string]$Path)
try {
    [System.IO.Directory]::SetCurrentDirectory("$PSScriptRoot/../")
    $ROOT_PATH = [System.IO.Directory]::GetCurrentDirectory()
    $CHANGELOG = [System.IO.Path]::Combine($ROOT_PATH, 'CHANGELOG.md')
    $readLines = [System.IO.File]::ReadAllLines($CHANGELOG)
    $header = $readLines -match '^## \[([\d.]+)\] - \d{4}-\d{2}-\d{2}'
} finally {
    if ($header[0]) {
        $writelines = @()
        foreach ($line in $readLines) {
            if ($line -eq $header[1]) { break }
            if ($line -ne $header[0] -and $line.Length -ne 0) {
                if ($line.StartsWith('[Full Changelog]')) { $writelines += '' }
                $writelines += $line
            }
        }
        if ($Path -and !([System.IO.File]::Exists($Path))) {
            $dirPath = [System.IO.Path]::GetDirectoryName($Path)
            if ([System.IO.Directory]::Exists($dirPath)) {
                [System.IO.Directory]::CreateDirectory($dirPath) | Out-Null
            }
            $fileName = [System.IO.Path]::GetFileName($Path)
            $newChangelogPath = [System.IO.Path]::Combine($dirPath, $fileName)
        } else {
            $newChangelogPath = [System.IO.Path]::Combine($ROOT_PATH, 'CHANGES.MD')
        }
        [System.IO.File]::WriteAllLines($newChangelogPath, $writelines)
        # replacing old date to current date
        $version = $header[0].Split(' ')[1].Trim('[]')
        $newDate = [string]::Format('{0:yyyy-MM-dd}', [datetime]::Now)
        $oldHeader = "^## \[$version\] - \d{4}-\d{2}-\d{2}"
        $newHeader = "## [$version] - $newDate"
        if ($oldHeader -ne $newHeader) {
            $newChangelogDate = $readLines -replace $oldHeader, $newHeader
            [System.IO.File]::WriteAllLines($CHANGELOG, $newChangelogDate)
        }
    }
}
