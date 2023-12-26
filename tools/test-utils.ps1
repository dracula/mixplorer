function Remove-EntryFromZip {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias('p')][string]$Path,
        [Parameter(Mandatory = $true, Position = 1)]
        [Alias('l')][string[]]$List
    )
    try {
        $null = [System.Reflection.Assembly]::LoadWithPartialName('System.IO.Compression')
        $stream = [System.IO.FileStream]::new($Path, [System.IO.FileMode]::Open)
        $mode = [System.IO.Compression.ZipArchiveMode]::Update
        $zip = [System.IO.Compression.ZipArchive]::new($stream, $mode)
        $zip.Entries.Where({ $List -contains $_.Name }).ForEach({ $_.Delete() })
    } finally {
        if ($zip) { $zip.Dispose() }
        if ($stream) { $stream.Dispose() }
    }
}

function Read-IniFile {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path,
        [Parameter(Position = 1)]
        [array]$Section
    )
    $ini = [System.Collections.Hashtable]::new()
    $lines = [System.IO.File]::ReadAllLines($Path)
    foreach ($line in $lines) {
        $line = $line.Trim('"', "'")
        if ($line -match '^[;#]') { continue }
        if ($line -match '\[(.+)\]') {
            $sec = $Matches[1]
            $ini[$sec] = [hashtable]::new()
        } elseif ($line -match '(.+?)\s*=\s*(.+)') {
            $key = $Matches[1]
            $val = $Matches[2]
            $ini[$sec][$key] = $val
        }
    }
    if ($Section) {
        $tmp = [System.Collections.Hashtable]::new()
        foreach ($key in $ini.Keys) {
            if ($key -in $Section) {
                $tmp[$key] = $ini[$key]
            }
        }
        return $tmp
    } else {
        return $ini
    }
}

function Get-FileMetaData {
    <#
.SYNOPSIS
    Get Detailed file information.
.DESCRIPTION
    Collects various data for each file, storing information in a hash table
.NOTES
    This function is not supported in Linux or MacOS and only for Windows
.LINK
    https://learn.microsoft.com/en-us/windows/win32/shell/folder-getdetailsof
    https://gist.github.com/woehrl01/5f50cb311f3ec711f6c776b2cb09c34e
.EXAMPLE
    $data = Get-FileMetaData -FilePath "c:\temp\myImage.jpg"
    $dimen = $data.'myImage.png' | Select-Object 'Dimensions'
    Write-Host $dimen.Dimensions
#>

    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$FilePath
    )

    $objInfo = [System.Collections.Hashtable]::new()

    foreach ($File in $FilePath) {
        if ([System.IO.File]::Exists($File)) {
            # Get detailed of file info
            $fileInfo = [System.IO.FileInfo]::new($File)

            try {
                # Create a Shell.Application COM object
                $objShell = New-Object -ComObject Shell.Application

                # Get the folder where the file is located
                $objFolder = $objShell.NameSpace($fileInfo.DirectoryName)

                # Get the file object from the folder
                $objFolderItem = $objFolder.ParseName($fileInfo.Name)

                # Retrieve and output details of the file without non-ASCII characters
                for ($j = 0; $j -lt 266; $j++) {
                    $objName = $objFolder.getDetailsOf($null, $j)
                    if (-not [string]::IsNullOrWhiteSpace($objName)) {
                        $objValue = $objFolder.GetDetailsOf($objFolderItem, $j)
                        if (-not [string]::IsNullOrWhiteSpace($objValue)) {
                            $hashName = $fileInfo.BaseName
                            $objValue = [regex]::Replace($objValue, '[^\x00-\x7F]', '')
                            if (-not $objInfo[$hashName]) { $objInfo[$hashName] = @{} }
                            $objInfo[$hashName][$objName] = $objValue
                        }
                    }
                }
            } finally {
                if ($objShell) {
                    $null = [System.Runtime.InteropServices.Marshal]::ReleaseComObject([System.__ComObject]$objShell)
                }
            }
        }
    }
    return $objInfo
}
