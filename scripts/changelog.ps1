#!/usr/bin/pwsh -c
param (
    # Save as output to file name.
    [Alias('o')][string]$OutFile,
    # Update header date to current date.
    [Alias('u')][switch]$NowDate
)

$ROOT_PATH = [System.IO.Path]::GetFullPath("$PSScriptRoot/..")
$inFileChangelog = [System.IO.Path]::Combine($ROOT_PATH, 'CHANGELOG.md')
if (!([System.IO.File]::Exists($inFileChangelog))) {
    "File could not be found '$inFileChangelog'."
    exit 1
}

if ($OutFile -and $OutFile.EndsWith('CHANGELOG.md')) {
    "File cannot be the same as '$inFileChangelog'."
    exit 1
}

[System.Console]::InputEncoding = [System.Console]::OutputEncoding = $OutputEncoding = [System.Text.UTF8Encoding]::new()
$readLines = [System.IO.File]::ReadAllLines($inFileChangelog).Trim()
$headings = $readLines -match '^##.\[([\d.]+)\].-.\d{4}-\d{2}-\d{2}'
$footers = $readLines -match '^\[Full Changelog\]\(.*\)'
$currentDate = [string]::Format('{0:yyyy-MM-dd}', [datetime]::Now)

$startHeader = $headings[0]

if ($startHeader) {
    $writeLines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $readLines) {
        if ($line -eq $footers[0]) { $writeLines.Add($line); break }
        if ($line -eq $headings[1]) { break }; $writeLines.Add($line)
    }
    if ($NowDate) {
        $semanticVersion = $startHeader.Split(' ')[1].Trim('[]')
        $newStartHeader = "## [$semanticVersion] - $currentDate"
        if ($startHeader -ne $newStartHeader) {
            $writeLines = $writeLines -replace $startHeader, $newStartHeader
        }
    }
    if ($OutFile) {
        $DirPath = [System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($OutFile))
        if (!([System.IO.Directory]::Exists($DirPath))) {
            [System.IO.Directory]::CreateDirectory($DirPath) | Out-Null
        }
        [System.IO.File]::WriteAllLines($OutFile, $writeLines)
    } else {
        return $writeLines
    }
} else {
    "Mismatched heading like '## [semver] - yyyy-MM-dd'."
    "example heading: ## [1.0.0] - $currentDate"
    exit 1
}
