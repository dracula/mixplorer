[CmdletBinding(DefaultParameterSetName = 'output')]
param (
    [Parameter(ParameterSetName = 'output')]
    [Alias('b')][switch]$Full,
    [Parameter(ParameterSetName = 'sample')]
    [Alias('e')][switch]$Example
)

$examples = @'
# Changelog

## [Unreleased]

<!-- changes that have been set but not yet released -->

## [2.0.0] - 2020-02-20

- [Added] - features
- [Fixed] - issues
- [Removed] - features

## [1.0.0] - 2021-10-22

- [Added] - Initial release.

[unreleased]: <https://github.com/owner/repo/compare/v2.0.0...HEAD>
[2.0.0]: <https://github.com/owner/repo/compare/v1.0.0...v2.0.0>
[1.0.0]: <https://github.com/owner/repo/commits/v1.0.0>

'@

if ($Example) { return $examples }

function regexm([object]$txt, [string]$rgx) {
    $regex = [regex]::Matches($txt, $rgx, 'multiline')
    return $regex.Groups.Value
}

$logFile = [System.IO.Path]::GetFullPath("$PSScriptRoot/../CHANGELOG.md")
if ([System.IO.File]::Exists($logFile)) {
    $content = [System.IO.File]::ReadAllText($logFile)
    $results = regexm $content '^##\s\[[\d.]+\][^#\n]+([\W\w]*?)^##[^#\n]+'
} else {
    "File does not exist '$logFile'."
    exit 1
}

if ($results) {
    $lines = $results -split '\r?\n' # Splitting using -split for all line endings
    $lines = $lines -notmatch '\<\!-[\W\w]*?-\>' # Removes <!-- comments -->
    $semvers = regexm $lines '##\s+\[[\d.]+\]\s+-\s+\d{4}-\d{2}-\d{2}' # Matches ## [semver] - yyyy-mm-dd
    $h1, $h2 = $semvers[0..1]
}
if ($h1 -and $h2) {
    $words = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $lines) {
        if ($line.Contains($h2)) { break }
        if ($line.Contains($h1) -and !$Full) { continue }
        $words.Add($line)
    }
    if ($words) {
        if (-not $words[0]) { $words.RemoveAt(0) }
        if (-not $words[-1]) { $words.RemoveAt($words.Count - 1) }
        if ($Full) {
            $head_url = regexm $content '\[[\d.]+\]:.*'
            $head_url = "`n" + $head_url[0]
        }
        return $words + $head_url
    }
} else {
    "Incorrect syntax! for example:`n" + $examples
    exit 1
}
