<#
.SYNOPSIS
    Build Dracula theme.
.DESCRIPTION
    A tool to build Dracula theme for MiXplorer.
.PARAMETER Name
    Specifies the name of the theme. If not provided, the default theme name is
    generated based on the provided accent.
.PARAMETER Accent
    Specifies the accent color for the theme. Available options: 'Pink', 'Purple'.
.PARAMETER Force
    Indicates whether to force overwrite existing files or directories.
.PARAMETER Force
    Indicates whether to force overwrite existing files or directories.
.NOTES
    Requires the 'resvg' CLI (https://github.com/linebender/resvg) to already
    be installed and available on PATH.

    Any property in config.ini's [colors] section whose value is the literal
    token '@accent' will be resolved at build time to the color selected via
    -Accent. This means adding/removing which UI elements follow the accent
    color only requires editing config.ini — build.ps1 never needs to be
    touched again for that purpose. The same applies to any icon SVG file
    that contains the default accent hex (#FF79C6): it will automatically be
    recolored for non-default accents.
.EXAMPLE
    .\build.ps1 -Name "MyTheme" -Accent "Pink"
    Generates a Dracula theme named 'MyTheme' with a pink accent color.
.EXAMPLE
    .\build.ps1 -Accent "Purple" -Force
    Generates a Dracula theme with a purple accent color and forces overwrite existing
    files or directories.
.LINK
    https://draculatheme.com/mixplorer
.LINK
    https://github.com/linebender/resvg
#>

[CmdletBinding()]
param (
    [Alias('n')][string]$Name,
    [ValidateSet('Pink', 'Purple')]
    [Alias('a')][string]$Accent = 'Pink',
    [Alias('f')][switch]$Force
)

# Single source of truth for accent colors. Add a new accent here (and to
# the ValidateSet above) and everything else keeps working automatically.
$ACCENT_COLORS = @{
    'Pink'   = '#FF79C6'
    'Purple' = '#BD93F9'
}
$ACCENT_TOKEN = '@accent'
$colorCode = $ACCENT_COLORS[$Accent]

$BASE_NAME = if ($Name) {
    [System.IO.Path]::GetFileNameWithoutExtension($Name)
} else {
    ('dracula', $Accent -join '-').ToLower()
}

[System.IO.Directory]::SetCurrentDirectory("$PSScriptRoot/..")
$ROOT_PATH = [System.IO.Path]::GetFullPath("$PSScriptRoot/..")
$BUILD_PATH = [System.IO.Path]::Combine($ROOT_PATH, 'build')
$SOURCE_PATH = [System.IO.Path]::Combine($ROOT_PATH, 'res')

# resvg must be installed and available on PATH before running this script
# (e.g. via the official releases: https://github.com/linebender/resvg/releases).
$resvgTool = (Get-Command -Name 'resvg' -CommandType Application -ErrorAction SilentlyContinue).Source
if (-not $resvgTool) {
    [System.Console]::WriteLine('resvg not found on PATH. Install it first: https://github.com/linebender/resvg/releases')
    exit 1
}

function ConvertTo-Png {
    param(
        [string]$ToolPath,
        [string]$InputSvg,
        [string]$OutputPng,
        [string]$Width,
        [string]$Height
    )
    $cliArgs = @($InputSvg, $OutputPng)
    if ($Width) { $cliArgs += '--width', $Width }
    if ($Height) { $cliArgs += '--height', $Height }
    & "$ToolPath" @cliArgs
}

$iniFile = [System.IO.Path]::Combine($SOURCE_PATH, 'config.ini')
$iniData = @{ 'properties' = [hashtable]::new() }
if ([System.IO.File]::Exists($iniFile)) {
    $lines = [System.IO.File]::ReadAllLines($iniFile)
    foreach ($line in $lines) {
        $line = $line.Trim('"', "'")
        if ($line) {
            if ($line -match '^[;#]') { continue }
            if ($line -match '^\[(.+)\]$') {
                $section = $Matches[1]
                $iniData[$section] = [hashtable]::new()
            } elseif ($line -match '^(.+?)\s*=\s*(.+)$') {
                $name = $Matches[1]
                $value = $Matches[2]
                if ($value) {
                    if ($section -match '^(colors|settings)$') {
                        if (-not $iniData['properties']) {
                            $iniData['properties'] = @{}
                        }
                        $iniData['properties'][$name] = $value
                        $iniData.Remove($section)
                    } else {
                        $iniData[$section][$name] = $value
                    }
                }
            }
        }
    }
} else {
    [System.Console]::WriteLine("File not found '$iniFile'.")
    exit 1
}

$iniData['properties']['title'] = if ($Accent -eq 'Pink') { 'Dracula' } else { "Dracula $Accent" }

# Resolve every '@accent' placeholder in config.ini to the chosen accent
# color. This replaces the old hardcoded key list: any property (existing
# or newly added later) that should follow the accent color just needs its
# value set to '@accent' in config.ini — nothing to update here.
foreach ($key in @($iniData['properties'].Keys)) {
    if ($iniData['properties'][$key] -eq $ACCENT_TOKEN) {
        $iniData['properties'][$key] = $colorCode
    }
}

$BUILD_NAME = [System.IO.Path]::Combine($BUILD_PATH, $BASE_NAME)
$BUILD_ICON = [System.IO.Path]::Combine($BUILD_NAME, 'drawable')
$BUILD_FONT = [System.IO.Path]::Combine($BUILD_NAME, 'fonts')
if ([System.IO.Directory]::Exists($BUILD_NAME)) {
    [System.IO.Directory]::Delete($BUILD_NAME, $true)
}
$buildPaths = @($BUILD_PATH, $BUILD_NAME, $BUILD_ICON, $BUILD_FONT)
foreach ($build in $buildPaths) {
    if (-not([System.IO.Directory]::Exists($build))) {
        $null = [System.IO.Directory]::CreateDirectory($build)
    }
}

foreach ($key in $iniData['fonts'].Keys) {
    # eg. 'fonts/FontName/FontName.ttf'
    $value = $iniData['fonts'][$key].ToString()
    if ($value) {
        if ($value.EndsWith('.ttf')) {
            $basedir, $basename = ($value -replace '\\', '/' -split '/')[-2..-1]
            $fromdir, $fromfile = (
                [System.IO.Path]::Combine($SOURCE_PATH, 'fonts', $basedir),
                [System.IO.Path]::Combine($SOURCE_PATH, 'fonts', $basedir, $basename)
            )
            if ([System.IO.Directory]::Exists($fromdir)) {
                if ([System.IO.File]::Exists($fromfile)) {
                    $iniData['properties'][$key] = "fonts/$basedir/$basename"
                    $destdir = [System.IO.Path]::Combine($BUILD_FONT, $basedir)
                    if (-not([System.IO.Directory]::Exists($destdir))) {
                        $null = [System.IO.Directory]::CreateDirectory($destdir)
                    }
                    $listFiles = [System.IO.Directory]::EnumerateFiles($fromdir)
                    foreach ($oldfile in $listFiles) {
                        $newfile = [System.IO.Path]::Combine(
                            $destdir, [System.IO.Path]::GetFileName($oldfile)
                        )
                        [System.IO.File]::Copy($oldfile, $newfile, $true)
                    }
                } else {
                    [System.Console]::WriteLine("File not found: '$fromfile'.")
                }
            } else {
                [System.Console]::WriteLine("Directory not found: '$fromdir'.")
            }
        } else {
            [System.Console]::WriteLine("Is not '.ttf' format: '$value'.")
        }
    }
}

foreach ($key in $iniData['icons'].Keys) {
    $svgfile = [System.IO.Path]::Combine($SOURCE_PATH, 'icons', "$key.svg")
    $pngfile = [System.IO.Path]::Combine($BUILD_ICON, "$key.png")
    if ([System.IO.File]::Exists($svgfile)) {
        $w, $h = $null, $null
        $dimensions = $iniData['icons'][$key]
        if ($dimensions) {
            $w, $h = ($dimensions -split ',')[0..1]
        }

        # Any icon whose SVG markup contains the default (Pink) accent hex
        # gets recolored to the selected accent automatically — no need to
        # special-case specific filenames like 'folder.svg' anymore.
        $renderInput = $svgfile
        $tmpfile = $null
        if ($colorCode -ne $ACCENT_COLORS['Pink']) {
            $svgContent = [System.IO.File]::ReadAllText($svgfile)
            if ($svgContent -match [regex]::Escape($ACCENT_COLORS['Pink'])) {
                $recolored = $svgContent -replace [regex]::Escape($ACCENT_COLORS['Pink']), $colorCode
                $tmpfile = [System.IO.Path]::Combine(
                    [System.IO.Path]::GetTempPath(), "$([guid]::NewGuid()).svg"
                )
                [System.IO.File]::WriteAllText($tmpfile, $recolored)
                $renderInput = $tmpfile
            }
        }

        ConvertTo-Png -ToolPath $resvgTool `
            -InputSvg $renderInput `
            -OutputPng $pngfile `
            -Width $w `
            -Height $h

        if ($tmpfile -and [System.IO.File]::Exists($tmpfile)) {
            [System.IO.File]::Delete($tmpfile)
        }
    } else {
        [System.Console]::WriteLine("File not found: '$svgfile'.")
    }
}

$xmlFile = [System.IO.Path]::Combine($BUILD_NAME, 'properties.xml')
try {
    $xmlDoc = [System.Xml.XmlDocument]::new()
    $null = $xmlDoc.AppendChild($xmlDoc.CreateXmlDeclaration('1.0', 'utf-8', $null))
    $root = $xmlDoc.CreateElement('properties')
    $null = $xmlDoc.AppendChild($root)
    foreach ($key in $iniData['properties'].Keys) {
        $value = $iniData['properties'][$key]
        $child = $xmlDoc.CreateElement('entry')
        $child.SetAttribute('key', $key)
        $child.InnerText = $value
        $null = $root.AppendChild($child)
    }
} finally {
    $xmlDoc.Save($xmlFile)
}

$zipFile = [System.IO.Path]::ChangeExtension($BUILD_NAME, 'mit')
if ([System.IO.File]::Exists($zipFile)) { [System.IO.File]::Delete($zipFile) }
try {
    $null = [System.Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem')
    $level = [System.IO.Compression.CompressionLevel]::Optimal
    [System.IO.Compression.ZipFile]::CreateFromDirectory(
        $BUILD_NAME, $zipFile, $level, $false
    )
    if ([System.IO.File]::Exists($zipFile)) {
        $mode = [System.IO.Compression.ZipArchiveMode]::Update
        $stream = [System.IO.Compression.ZipFile]::Open($zipFile, $mode)
        $files = @('screenshot.png', 'README.md', 'LICENSE')
        foreach ($file in $files) {
            $source = [System.IO.Path]::Combine($ROOT_PATH, $file)
            if ([System.IO.File]::Exists($source)) {
                $null = [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                    $stream, $source, $file, $level
                )
            } else {
                [System.Console]::WriteLine("File not found '$file'.")
            }
        }
    }
} finally {
    if ($stream) { $stream.Dispose() }
}

$shaFile = [System.IO.Path]::ChangeExtension($zipFile, 'sha1')
if ([System.IO.File]::Exists($zipFile)) {
    try {
        $alg = [System.Security.Cryptography.HashAlgorithm]::Create('SHA1')
        $fs = [System.IO.File]::OpenRead($zipFile)
        $bytes = $alg.ComputeHash($fs).ForEach({ $_.ToString('x2') })
        $texts = [string]::Join('', $bytes) + ' *' + [System.IO.Path]::GetFileName($zipFile)
        [System.IO.File]::WriteAllText($shaFile, $texts)
    } finally {
        if ($fs) { $fs.Dispose() }
        if ($alg) { $alg.Dispose() }
    }
}

if ($Force -and [System.IO.Directory]::Exists($BUILD_NAME)) {
    [System.IO.Directory]::Delete($BUILD_NAME, $true)
}

[System.IO.Directory]::GetFiles($BUILD_PATH, "$BASE_NAME.*")
