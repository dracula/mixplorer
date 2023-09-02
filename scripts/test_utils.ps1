$ROOT_PATH = Resolve-Path $(Join-Path $PSScriptRoot '..')

function cleanup_build([Alias('r')][switch]$Recurse) {
    $options = @{
        LiteralPath = "$ROOT_PATH/build", "$ROOT_PATH/res/drawable/*.png"
        File        = $true
        Recurse     = $Recurse
    }
    Get-ChildItem @options | Remove-Item -Force
}

function rename_svgs([string]$dir, [string]$str) {
    Get-ChildItem $dir -Filter '*.svg' -File | ForEach-Object {
        $oldName = $_.BaseName
        $extName = $_.Extension
        $dirPath = $_.DirectoryName
        if ($oldName -match $str) {
            $newName = $oldName -replace $str
            $outPath = "$dirPath/" + $newName + $extName
            Move-Item -Path $_.FullName -Destination $outPath -Force
        }
    }
}

function remove_entry_zip {
    # source https://stackoverflow.com/a/20276205
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias('p')][string]$Path,
        [Parameter(Mandatory = $true, Position = 1)]
        [Alias('l')][string[]]$List
    )
    try {
        [Reflection.Assembly]::LoadWithPartialName('System.IO.Compression') | Out-Null
        $stream = [System.IO.FileStream]::new($Path, [System.IO.FileMode]::Open)
        $mode = [System.IO.Compression.ZipArchiveMode]::Update
        $zip = [System.IO.Compression.ZipArchive]::new($stream, $mode)
        $zip.Entries.Where({ $List -contains $_.Name }).ForEach({ $_.Delete() })
    } finally {
        $zip.Dispose(); $stream.Close(); $stream.Dispose()
    }
}

function delete_git_tag([string[]]$tag, [switch]$all) {
    Get-Command 'git', 'gh' -ErrorAction Stop | Out-Null
    git fetch --tags
    if (!$tag) { 'Require tag name.'; exit 1 }
    if ($all) { $tag = git tag --list }
    # https://stackoverflow.com/a/44702758
    foreach ($ver in $tag) {
        if ((git tag --list) -match $ver) {
            git tag --delete $ver
            git push origin --delete $ver
            gh release delete $ver --yes
        }
    }
}

function Get-FileMetaData {
    # Source: https://gallery.technet.microsoft.com/scriptcenter/Get-FileMetaData-3a7ddea7
    <#
    .SYNOPSIS
        Get-FileMetaData returns metadata information about a single file.
    .DESCRIPTION
        This function will return all metadata information about a specific file. It can be used to access the information stored in the filesystem.
    .EXAMPLE
        Get-FileMetaData -File "c:\temp\image.jpg"
        Get information about an image file.
    .EXAMPLE
        Get-FileMetaData -File "c:\temp\image.jpg" | Select Dimensions
        Show the dimensions of the image.
    .EXAMPLE
        Get-ChildItem -Path .\ -Filter *.exe | foreach {Get-FileMetaData -File $_.Name | Select Name,"File version"}
        Show the file version of all binary files in the current folder.
    #>
    param([Parameter(Mandatory = $True)][string]$File)
    if (!(Test-Path $File -PathType Leaf)) {
        "File does not exist: $File"
        exit 1
    }
    $fileinfo = Get-ChildItem $File
    $pathname = $fileinfo.DirectoryName
    $filename = $fileinfo.Name
    $property = @{}
    try {
        $shellobj = New-Object -ComObject Shell.Application
        $folderobj = $shellobj.NameSpace($pathname)
        $fileobj = $folderobj.ParseName($filename)
        for ($i = 0; $i -le 294; $i++) {
            $name = $folderobj.getDetailsOf($null, $i);
            if ($name) {
                $value = $folderobj.getDetailsOf($fileobj, $i);
                if ($value) { $property["$name"] = "$value" }
            }
        }
    } finally {
        if ($shellobj) {
            [System.Runtime.InteropServices.Marshal]::ReleaseComObject([System.__ComObject]$shellobj) | Out-Null
        }
    }
    return New-Object psobject -Property $property
}
