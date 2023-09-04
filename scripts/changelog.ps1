[CmdletBinding(DefaultParameterSetName = 'WithHeader')]
param (
    # Save as output to file name.
    [Parameter(ParameterSetName = 'WithHeader')]
    [Parameter(ParameterSetName = 'NoWithHeader')]
    [Alias('o')][string]$OutFile,
    # Update header date to current date.
    [Parameter(ParameterSetName = 'WithHeader')]
    [Alias('u')][switch]$NowDate,
    # Remove first header.
    [Parameter(ParameterSetName = 'NoWithHeader')]
    [Alias('n')][switch]$NoHeader
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
$footers = $readLines -match '\[Full Changelog\]'
$headDefs = $readLines -match '\[([\d.]+)\]\:'
$currentDate = [string]::Format('{0:yyyy-MM-dd}', [datetime]::Now)

$startHeader = $headings[0]

if ($startHeader) {
    $writeLines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $readLines) {
        $line = $line.Trim()
        if ($line.Contains($headings[1])) { break };
        if ($line.Contains($footers[0])) { $writeLines.Add($line); break }
        if ($line.Contains($startHeader) -and $NowDate) {
            $semanticVersion = $startHeader.Split(' ')[1].Trim('[]')
            $newStartHeader = "## [$semanticVersion] - $currentDate"
            $line = $line -replace $startHeader, $newStartHeader
        }
        $writeLines.Add($line)
    }
    if ($NoHeader) {
        if ($writeLines[0].Contains($startHeader)) { $writeLines.RemoveAt(0) }
        if ($writeLines[0].Length -eq 0) { $writeLines.RemoveAt(0) }
    } elseif ($headDefs[0]) {
        $writeLines.Add($null); $writeLines.Add($headDefs[0])
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
