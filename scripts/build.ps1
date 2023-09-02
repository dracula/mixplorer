#!/usr/bin/pwsh -c
<#
.SYNOPSIS
    Build Dracula theme.
.DESCRIPTION
    A tool to build Dracula theme for MiXplorer.
.EXAMPLE
    ./build.ps1 -Name Dracula -Accent Purple -Verbose
    This result in a Dracula.mit theme with a Purple accent and
    by default the Accent is Pink.
.NOTES
    rsvg-convert or cairosvg is required to convert svg to png format.
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
begin {
    # [System.Console]::WriteLine('Initializing...')
    [System.IO.Directory]::SetCurrentDirectory("$PSScriptRoot/../")
    $ROOT_PATH = [System.IO.Directory]::GetCurrentDirectory()
    if ($Accent -eq 'Purple') {
        $titleName = 'Dracula Purple'; $accentHex = '#BD93F9'
    } else {
        $titleName = 'Dracula'; $accentHex = '#FF79C6'
    }
    if ($Name) {
        $BASE_NAME = [System.IO.Path]::GetFileNameWithoutExtension($Name)
    } else {
        $BASE_NAME = 'dracula-' + $Accent.ToLower()
    }
    $templates = [System.Collections.Hashtable]@{
        properties = [System.Collections.Hashtable]::new();
        fonts      = [System.Collections.Hashtable]::new();
        icons      = [System.Collections.Hashtable]::new();
    }
    $SOURCE_ROOT = [System.IO.Path]::Combine($ROOT_PATH, 'res')
    # validate configuration files such as ConvertFrom-StringData
    $fileTemplate = [System.IO.Path]::Combine($SOURCE_ROOT, 'templates.txt')
    if ([System.IO.File]::Exists($fileTemplate)) {
        foreach ($line in [System.IO.File]::ReadAllLines($fileTemplate)) {
            $line = $line.Trim().Trim('"').Trim("'")
            if (!$line.StartsWith('#') -and !$line.Length -eq 0) {
                [string]$value = $line.Split('=')[1].Trim().Trim('"').Trim("'")
                [string]$name = $line.Split('=')[0].Trim().Trim('"').Trim("'")
                switch ($name) {
                    'font_primary' { $templates.fonts.Add($name, $value) }
                    'font_secondary' { $templates.fonts.Add($name, $value) }
                    'font_title' { $templates.fonts.Add($name, $value) }
                    'font_popup' { $templates.fonts.Add($name, $value) }
                    'font_editor' { $templates.fonts.Add($name, $value) }
                    'font_hex' { $templates.fonts.Add($name, $value) }
                    'title' { $templates.properties.Add($name, $titleName) }
                    'highlight_bar_action_buttons' { $templates.properties.Add($name, $accentHex) }
                    'highlight_bar_main_buttons' { $templates.properties.Add($name, $accentHex) }
                    'highlight_bar_tab_buttons' { $templates.properties.Add($name, $accentHex) }
                    'highlight_bar_tool_buttons' { $templates.properties.Add($name, $accentHex) }
                    'highlight_visited_folder' { $templates.properties.Add($name, $accentHex) }
                    'text_bar_tab_selected' { $templates.properties.Add($name, $accentHex) }
                    'text_button_inverse' { $templates.properties.Add($name, $accentHex) }
                    'text_edit_selection_foreground' { $templates.properties.Add($name, $accentHex) }
                    'text_grid_primary_inverse' { $templates.properties.Add($name, $accentHex) }
                    'text_link_pressed' { $templates.properties.Add($name, $accentHex) }
                    'text_popup_header' { $templates.properties.Add($name, $accentHex) }
                    'text_popup_primary_inverse' { $templates.properties.Add($name, $accentHex) }
                    'text_popup_secondary_inverse' { $templates.properties.Add($name, $accentHex) }
                    'tint_bar_tab_icons' { $templates.properties.Add($name, $accentHex) }
                    'tint_page_separator' { $templates.properties.Add($name, $accentHex) }
                    'tint_popup_icons' { $templates.properties.Add($name, $accentHex) }
                    'tint_progress_bar' { $templates.properties.Add($name, $accentHex) }
                    'tint_scroll_thumbs' { $templates.properties.Add($name, $accentHex) }
                    'tint_tab_indicator_selected' { $templates.properties.Add($name, $accentHex) }
                    Default { $templates.properties.Add($name, $value) }
                }
            }
        }
    } else {
        [System.Console]::WriteLine("Cannot found: $fileTemplate.")
        exit 1
    }
    $sourceIconDir = [System.IO.Path]::Combine($SOURCE_ROOT, 'icons')
    $iconConfigFile = [System.IO.Path]::Combine($SOURCE_ROOT, 'icons.csv')
    if ([System.IO.File]::Exists($iconConfigFile)) {
        $read = [System.IO.File]::ReadAllText($iconConfigFile)
        $data = ConvertFrom-Csv -InputObject $read -Delimiter ','
        for ($i = 0; $i -lt $data.Count; $i++) {
            $name = $data.name[$i]
            $size = $data.size[$i]
            $templates.icons.Add($name, $size)
        }
    } else {
        [System.Console]::WriteLine("Cannot found: $iconConfigFile.")
        exit 1
    }
    if ($IsWindows -or $PSEdition -eq 'Desktop') {
        $rsvg_convert = [System.IO.Path]::Combine($ROOT_PATH, 'bin', 'rsvg-convert.exe')
        if ([System.IO.File]::Exists($rsvg_convert)) {
            $addPath = [System.IO.Path]::GetDirectoryName($rsvg_convert)
            $oldPath = [System.Environment]::GetEnvironmentVariable('Path')
            $newpath = ($oldPath.Split(';') -notlike $addPath) + $addPath -join ';'
            [System.Environment]::SetEnvironmentVariable('Path', $newpath)
        }
    }
    $svgTool = ('rsvg-convert', 'cairosvg').ForEach({ if (Get-Command -Name $_ -ea:0) { $_ } })[0]
    if (-not($svgTool)) {
        [System.Console]::WriteLine("Need to install 'rsvg-convert' or 'cairosvg'.")
        exit 1
    } else {
        New-Alias -Name 'svg2png' -Value "$svgTool" -Description 'Convert svg to png'
    }
}
process {
    [System.Console]::WriteLine("Building name '$BASE_NAME' with accent '$Accent'.")
    $BUILD_ROOT = [System.IO.Path]::Combine($ROOT_PATH, 'build')
    $buildNameDir = [System.IO.Path]::Combine($BUILD_ROOT, $BASE_NAME)
    $buildFontDir = [System.IO.Path]::Combine($buildNameDir, 'fonts')
    $buildIconDir = [System.IO.Path]::Combine($buildNameDir, 'drawable')
    if ([System.IO.Directory]::Exists($buildNameDir)) {
        [System.IO.Directory]::Delete($buildNameDir, $true)
    }
    foreach ($buildDir in $BUILD_ROOT, $buildFontDir, $buildIconDir) {
        if (!([System.IO.Directory]::Exists($buildDir))) {
            [System.IO.Directory]::CreateDirectory($buildDir) | Out-Null
        }
    }
    [System.Console]::WriteLine('Copying font files...')
    $sourceFontDir = [System.IO.Path]::Combine($SOURCE_ROOT, 'fonts')
    foreach ($font in $templates.fonts.keys) {
        if ($templates.fonts[$font]) {
            $fontFileValue = $templates.fonts[$font] -replace '\\', '/'
            $fontFileName = $fontFileValue.Split('/')[-1]
            $fontDirName = $fontFileValue.Split('/')[-2]
            if ($fontFileValue.EndsWith('.ttf')) {
                if ($fontFileValue -ne "fonts/$fontDirName/$fontFileName") {
                    $fontFileValue = "fonts/$fontDirName/$fontFileName"
                }
                $fromDirPath = [System.IO.Path]::Combine($sourceFontDir, $fontDirName)
                $fromFilePath = [System.IO.Path]::Combine($fromDirPath, $fontFileName)
                if ([System.IO.File]::Exists($fromFilePath)) {
                    $templates.properties[$font] = $fontFileValue
                    $destDirPath = [System.IO.Path]::Combine($buildFontDir, $fontDirName)
                    if (!([System.IO.Directory]::Exists($destDirPath))) {
                        [System.IO.Directory]::CreateDirectory($destDirPath) | Out-Null
                    }
                    foreach ($itemFile in [System.IO.Directory]::EnumerateFiles($fromDirPath)) {
                        $itemName = [System.IO.Path]::GetFileName($itemFile)
                        $destFilePath = [System.IO.Path]::Combine($destDirPath, $itemName)
                        if (!([System.IO.File]::Exists($destFilePath))) {
                            [System.IO.File]::Copy($itemFile, $destFilePath, $true)
                        }
                    }
                } else {
                    [System.Console]::WriteLine("Cannot found: $fromFilePath.")
                }
            } else {
                [System.Console]::WriteLine("Is not ttf format: $fontFileValue.")
            }
        } else {
            $templates.properties.Remove($font)
        }
    }
    [System.Console]::WriteLine('Converting icon files...')
    foreach ($icon in $templates.icons.keys) {
        $inputSvgFile = [System.IO.Path]::Combine($sourceIconDir, "$icon.svg")
        $outputPngFile = [System.IO.Path]::Combine($buildIconDir, "$icon.png")
        if ([System.IO.File]::Exists($inputSvgFile)) {
            try {
                $default_folder_icon = $null; $purple_folder_icon = $null
                if ($inputSvgFile.EndsWith('folder.svg') -and ($Accent -eq 'Purple')) {
                    $default_folder_icon = [System.IO.File]::ReadAllText($inputSvgFile)
                    $purple_folder_icon = $default_folder_icon -replace '\"#FF79C6\"', '"#BD93F9"'
                    [System.IO.File]::WriteAllText($inputSvgFile, $purple_folder_icon)
                }
                $outputPngSize = $templates.icons[$icon]
                if ($outputPngSize) { $resizes = '--width', "$outputPngSize", '--height', "$outputPngSize" }
                svg2png "$inputSvgFile" '--output' "$outputPngFile" $resizes
            } finally {
                if ($default_folder_icon) {
                    [System.IO.File]::WriteAllText($inputSvgFile, $default_folder_icon)
                }
            }
        } else {
            [System.Console]::WriteLine("Cannot found: $inputSvgFile.")
        }
    }
    try {
        [System.Console]::WriteLine('Generating properties file...')
        $buildPropXml = [System.IO.Path]::Combine($buildNameDir, 'properties.xml')
        $xmldoc = New-Object -TypeName System.Xml.XmlDocument
        $xmldec = $xmldoc.CreateXmlDeclaration('1.0', 'utf-8', $null)
        $xmldoc.AppendChild($xmldec) | Out-Null
        $elroot = $xmldoc.CreateElement('properties')
        $xmldoc.AppendChild($elroot) | Out-Null
        foreach ($item in $templates.properties.keys) {
            if ($templates.properties[$item]) {
                $child = $xmldoc.CreateElement('entry')
                $child.SetAttribute('key', $item)
                $child.InnerText = $templates.properties[$item]
                $elroot.AppendChild($child) | Out-Null
            }
        }
    } finally {
        $xmldoc.Save($buildPropXml)
    }
}
end {
    try {
        [System.Console]::WriteLine('Packaging theme files...')
        $filepack = $buildNameDir + '.mit'
        if ([System.IO.File]::Exists($filepack)) {
            [System.IO.File]::Delete($filepack)
        }
        [System.Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem') | Out-Null
        $level = [System.IO.Compression.CompressionLevel]::Optimal
        [System.IO.Compression.ZipFile]::CreateFromDirectory($buildNameDir, $filepack, $level, $false)
        $mode = [System.IO.Compression.ZipArchiveMode]::Update
        $stream = [System.IO.Compression.ZipFile]::Open($filepack, $mode)
        foreach ($file in 'screenshot.png', 'README.md', 'LICENSE') {
            $path = [System.IO.Path]::Combine($ROOT_PATH, $file)
            if ([System.IO.File]::Exists($path)) {
                [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                    $stream, $path, $file, $level) | Out-Null
            }
        }
    } finally {
        $stream.Dispose()
    }
    try {
        $filehash = $filepack + '.sha1'
        $alg = [System.Security.Cryptography.HashAlgorithm]::Create('SHA1')
        $rel = [System.IO.Path]::GetFileName($filepack)
        $fs = [System.IO.File]::OpenRead($filepack)
        $bytes = $alg.ComputeHash($fs).ForEach({ $_.ToString('x2') })
        $lines = [string]::Join('', $bytes) + ' *' + $rel
        [System.IO.File]::WriteAllText($filehash, $lines)
    } finally {
        $fs.Dispose()
        $alg.Dispose()
    }
    if ($Force -and [System.IO.Directory]::Exists($buildNameDir)) {
        [System.IO.Directory]::Delete($buildNameDir, $true)
    }
    [System.Console]::WriteLine('Finished. packaged file results:')
    [System.IO.Directory]::GetFiles($BUILD_ROOT, "$BASE_NAME.*")
}
