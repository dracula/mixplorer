#Requires -PSEdition Core

<#
.SYNOPSIS
    Build dracula theme
.DESCRIPTION
    A tool to build Dracula theme for MiXplorer
.EXAMPLE
    ./build.ps1 -Name dracula -Verbose
.NOTES
    Requires 7-zip and rsvg-convert or cairosvg
.LINK
    https://draculatheme.com/mixplorer
#>

[CmdletBinding()]
param (
    [Parameter(ValueFromPipeline)][Alias('n')][string]$Name,
    [Parameter()][Alias('f')][switch]$Force
)

Set-StrictMode -Off

Write-Verbose 'Validating...'

$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

$ROOT_PATH = Resolve-Path $(Join-Path $PSScriptRoot '..')

Set-Location $ROOT_PATH

$TOOLS_DIR = Join-Path $ROOT_PATH 'bin'
$BUILD_DIR = Join-Path $ROOT_PATH 'build'
$ICONS_DIR = Join-Path $ROOT_PATH 'res' 'drawable'

$BUILD_BASENAME = if ($Name) {
    $Name -replace '/', '-'
}
elseif ($env:BASE_NAME) {
    $env:BASE_NAME -replace '/', '-'
}
else {
    'build-' + [System.Guid]::NewGuid().Guid.Split('-')[1]
}

Write-Verbose "Building name: $BUILD_BASENAME"

$BUILD_FILENAME = Join-Path $BUILD_DIR $BUILD_BASENAME

foreach ($dir in $($BUILD_DIR, $TOOLS_DIR)) {
    if (!(Test-Path $dir -PathType Container)) {
        New-Item $dir -ItemType Directory -Force
    }
}

$env:PATH = $env:PATH -replace ($TOOLS_DIR + [System.IO.Path]::PathSeparator), ''
$env:PATH = ($TOOLS_DIR + [System.IO.Path]::PathSeparator) + $env:PATH

if (!(Get-Command '7z' -ErrorAction SilentlyContinue)) {
    if (!$IsWindows) { Write-Warning "Need to install '7-Zip'."; exit 1 }
    try {
        Write-Verbose 'Downloading 7-Zip...'
        $site_url = 'https://www.7-zip.org'
        $metadata = $(Invoke-WebRequest "$site_url/download.html" -Verbose:$false).Links.href
        $out_name = $metadata -match $(if ([Environment]::Is64BitProcess) { '7z\d.*-x64.msi' } else { '7z\d*.msi' }) | Select-Object -First 1
        $out_file = Join-Path $TOOLS_DIR $out_name.Split('/')[-1]
        Invoke-WebRequest -OutFile $out_file -Uri "$site_url/$out_name" -Verbose:$false
        Write-Verbose 'Installing 7-Zip...'
        $msi_exec = $(Get-Command 'msiexec').Path
        & $msi_exec '/i' "$out_file" "TARGETDIR=$TOOLS_DIR" '/qb'
        $p7zip = Join-Path $TOOLS_DIR '7z.exe'
    }
    catch { throw }
} else {
    $p7zip = $(Get-Command '7z').Path
}

if (!(Get-Command 'rsvg-convert' -ErrorAction SilentlyContinue)) {
    if (Get-Command 'cairosvg' -ErrorAction Ignore) {
        $librsvg = $(Get-Command 'cairosvg').Path
    }
    elseif (Get-Command 'pip3' -ErrorAction Ignore) {
        try {
            & $(Get-Command 'pip3').Path install cairosvg
            & $librsvg = $(Get-Command 'cairosvg').Path
        }
        catch {
            throw
        }
    }
    elseif ($IsWindows) {
        try {
            Write-Verbose "Installing 'rsvg-convert'..."
            $site_url = 'https://jaist.dl.sourceforge.net/project/tumagcc/rsvg-convert-2.40.20.7z'
            $out_file = Join-Path $TOOLS_DIR $site_url.Split('/')[-1]
            Invoke-WebRequest -OutFile $out_file -Uri $site_url -Verbose:$false
            & $p7zip 'x' "$out_file" "-o$TOOLS_DIR" '-y' '-bso0' '-bsp0'
            $librsvg = Join-Path $TOOLS_DIR 'rsvg-convert.exe'
        }
        catch {
            throw
        }
    }
    if (!$librsvg) {
        Write-Warning "Need to install 'rsvg-convert'."
        exit 1
    }
} else {
    $librsvg = $(Get-Command 'rsvg-convert').Path
}

Write-Verbose 'Converting tools:'; "- $p7zip", "- $librsvg" | Write-Verbose

if ($Force) {
    Write-Verbose 'Removing previous build files...'
    Get-ChildItem $BUILD_DIR -File -Recurse | Remove-Item -Force
}

Get-ChildItem $ICONS_DIR -Filter '*.png' -File | Remove-Item -Force

try {
    Write-Verbose 'Converting SVG to PNG files:'
    $metadata = Join-Path $ROOT_PATH 'res' 'drawable.csv'
    Get-Content $metadata | ConvertFrom-Csv | ForEach-Object {
        $i = Join-Path $ICONS_DIR $($_.name + '.svg')
        if (Test-Path $i) {
            $w = $_.size; $h = $_.size
            $o = Join-Path $ICONS_DIR $($_.name + '.png')
            Write-Verbose "- $(Join-Path 'drawable' $($_.name + '.svg'))"
            & $librsvg '--width' "$w" '--height' "$h" '--output' "$o" "$i"
        }
        else {
            Write-Warning "Cannot found $i"
        }
    }
    $file_zip = $BUILD_FILENAME + '.zip'
    $BUILD_INCLUDES = 'res', 'screenshot.png', 'README.md', 'LICENSE'
    Out-File 'includes.txt' -Force -InputObject $(Get-ChildItem $(Resolve-Path $BUILD_INCLUDES)).FullName
    if ($PSBoundParameters['Verbose'] -eq $true) { $q = '-bb2' } else { $q = '-bso0', '-bsp0' }
    & $p7zip 'a' '-tzip' "$file_zip" '@includes.txt' '-xr!*.ai' '-xr!*.csv' '-xr!*.svg' '-y' $q | Write-Verbose
    Remove-Item 'includes.txt' -Force; Write-Verbose '';

    $file_mit = $BUILD_FILENAME + '.mit'
    Move-Item $file_zip -Destination $file_mit -Force
    Write-Verbose "The result file: $file_mit."

    $file_sum = $BUILD_FILENAME + '.sha1.txt'
    $hashes = $(Get-FileHash $file_mit SHA1).Hash.ToLower() + " *$BUILD_BASENAME.mit"
    Out-File $file_sum -InputObject $hashes -NoNewline -Force
    Write-Verbose "The hashes file: $file_sum."
}
catch { throw }

exit $LASTEXITCODE
