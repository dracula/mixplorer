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
.NOTES
    This script assumes the availability of 'rsvg-convert' or 'cairosvg' tools for
    SVG to PNG conversion.
.EXAMPLE
    .\build.ps1 -Name "MyTheme" -Accent "Pink"
    Generates a Dracula theme named 'MyTheme' with a pink accent color.
.EXAMPLE
    .\build.ps1 -Accent "Purple" -Force
    Generates a Dracula theme with a purple accent color and forces overwrite existing
    files or directories.
.LINK
    https://draculatheme.com/mixplorer
#>

[CmdletBinding()]
param (
    [Alias('n')][string]$Name,
    [ValidateSet('Pink', 'Purple')]
    [Alias('a')][string]$Accent = 'Pink',
    [Alias('f')][switch]$Force
)

$BASE_NAME = if ($Name) {
    [System.IO.Path]::GetFileNameWithoutExtension($Name)
} else {
    ('dracula', $Accent -join '-').ToLower()
}

[System.IO.Directory]::SetCurrentDirectory("$PSScriptRoot/..")
$ROOT_PATH = [System.IO.Path]::GetFullPath("$PSScriptRoot/..")
$BUILD_PATH = [System.IO.Path]::Combine($ROOT_PATH, 'build')
$SOURCE_PATH = [System.IO.Path]::Combine($ROOT_PATH, 'res')

# Check executable 'rsvg-convert' or 'cairosvg' path
$svgTools = @('rsvg-convert', 'cairosvg')
$svgTool , $sep = $null, [System.IO.Path]::PathSeparator
if ($IsWindows -or $PSEdition -eq 'Desktop') {
    $svgTools = $svgTools.ForEach({ [System.IO.Path]::ChangeExtension($_, 'exe') })
    $rsvg_convert = [System.IO.Path]::Combine($ROOT_PATH, 'bin', 'rsvg-convert.exe')
    if ([System.IO.File]::Exists($rsvg_convert)) {
        # $svgTool = [System.IO.FileInfo]::new($rsvg_convert)
        $addPath = [System.IO.Path]::GetDirectoryName($rsvg_convert)
        $oldPath = [System.Environment]::GetEnvironmentVariable('Path')
        $newPath = ($oldPath -split $sep -notlike $addPath) + $addPath -join $sep
        [System.Environment]::SetEnvironmentVariable('Path', $newPath)
    }
}
foreach ($tool in $svgTools) {
    $paths = $env:PATH -split $sep
    foreach ($path in $paths) {
        $toolPath = [System.IO.Path]::Combine($path, $tool)
        if (-not $svgTool -and [System.IO.File]::Exists($toolPath)) {
            $svgTool = [System.IO.FileInfo]::new($toolPath)
        }
    }
}
if (-not $svgTool) {
    [System.Console]::WriteLine("No svg tools 'rsvg-convert' or 'cairosvg' found!")
    exit 1
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

if ($Accent -eq 'Purple') {
    $colorCode = '#BD93F9'
    $iniData['properties']['title'] = 'Dracula Purple'
} else {
    $iniData['properties']['title'] = 'Dracula'
    $colorCode = '#FF79C6'
}

@(
    'highlight_bar_action_buttons', 'highlight_bar_main_buttons',
    'highlight_bar_tab_buttons', 'highlight_bar_tool_buttons',
    'highlight_visited_folder', 'text_bar_tab_selected',
    'text_button_inverse', 'text_edit_selection_foreground',
    'text_grid_primary_inverse', 'text_link_pressed',
    'text_popup_header', 'text_popup_primary_inverse',
    'text_popup_secondary_inverse', 'tint_bar_tab_icons',
    'tint_page_separator', 'tint_popup_icons', 'tint_progress_bar',
    'tint_scroll_thumbs', 'tint_tab_indicator_selected'
).ForEach({ $iniData['properties']["$_"] = "$colorCode" })

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
        $options = '--format', 'png', '--output', $pngfile, $svgfile
        $dimensions = $iniData['icons'][$key]
        if ($dimensions) {
            $w, $h = ($dimensions -split ',')[0..1]
            if ($w) { $options += '--width', $w }
            if ($h) { $options += '--height', $h }
        }
        if ($svgFile.EndsWith('folder.svg') -and ($Accent -eq 'Purple')) {
            $default = [System.IO.File]::ReadAllText($svgFile)
            $purples = $default -replace '#FF79C6', '#BD93F9'
            $tmpfile = [System.IO.Path]::GetTempFileName()
            [System.IO.File]::WriteAllText($tmpfile, $purples)
            $options = ($options -notlike $svgfile) + $tmpfile
        }
        & "$svgTool" $options
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

# [System.IO.Directory]::GetFiles($BUILD_PATH, "$BASE_NAME.*")

