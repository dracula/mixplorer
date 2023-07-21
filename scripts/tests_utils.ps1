$ROOT_PATH = Resolve-Path $(Join-Path $PSScriptRoot '..')

function __cleanup_build([switch]$r) {
    Get-ChildItem $(
        "$ROOT_PATH/build",
        "$ROOT_PATH/res/drawable/*.png"
    ) -File -Recurse:$r | Remove-Item -Force
}

function __rename_svgs($src, [string]$str) {
    Get-ChildItem $src -Filter '*.svg' -File | ForEach-Object {
        if ($_.BaseName -match $str) {
            Move-Item $_.FullName $($_.FullName -replace $str) -Force
        }
    }
}

function __delete_tags($tags) {
    try {
        Get-Command 'git', 'gh' -ErrorAction Stop | Out-Null
        # https://stackoverflow.com/a/44702758
        git fetch --tags
        if (!$tags) { $tags = git tag --list }
        foreach ($tag in $tags) {
            git tag --delete $tag
            git push origin --delete $tag
            gh release delete $tag --yes
        }
    }
    catch {
        throw
    }
}
