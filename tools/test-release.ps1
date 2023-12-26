[CmdletBinding(DefaultParameterSetName = 'usetag')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'usetag')]
    [string][alias('t')]$tagName,
    [Parameter(ParameterSetName = 'usetag')]
    [switch][alias('d')]$deleteAllTag,
    [Parameter(ParameterSetName = 'nottag')]
    [switch][alias('a')]$pushAddAll
)

# ./tools/test_release.ps1 'v1.3.0'

foreach ($tool in 'git', 'gh') {
    if (-not(Get-Command $tool -ea:0)) {
        Write-Host "Please install: $tool."
        exit 1
    }
}

$REPOSITORY = 'sionta/mixplorer'

function delete_release($tag) {
    if (-not $tag) { $tag = $tagName }
    $release = gh api repos/$REPOSITORY/releases | ConvertFrom-Json
    if ($release.tag_name -eq $tagName) {
        gh release delete $tagName --repo $REPOSITORY --yes --cleanup-tag
    }
}

function delete_tag_name {
    # delete tag release
    delete_release
    # delete tag locally
    $tagLocal = git tag -l | Where-Object { $_ -eq $tagName }
    if ($tagLocal) { git tag -d $tagName }
    # delete tag remotely
    $tagRemote = git ls-remote --tags origin $tagName
    if ($tagRemote) { git push origin --delete $tagName }
}

function create_tag_name {
    delete_tag_name $tagName
    $tagMessage = "Release version $($tagName -replace 'v','')"
    git tag -a $tagName -m $tagMessage
    git push origin $tagName
}

function push_add_all {
    $message = $([System.Guid]::NewGuid()).ToString().Split('-')[0]
    $branch = git rev-parse --abbrev-ref HEAD
    git add .
    git commit -m $message
    git push origin $branch
}

function delete_all_tag {
    # delete all tag locally
    git tag | ForEach-Object { git tag -d $_ }
    # delete all tag remotely
    git ls-remote --tags origin | ForEach-Object {
        $remoteTag = $_.Split('/')[-1]
        # delete all releases
        delete_release $remoteTag
        git push origin --delete $remoteTag
    }
    return
}

if ($pushAddAll) { return push_add_all }
if ($deleteAllTag) { return delete_all_tag }

push_add_all
delete_release
delete_tag_name
create_tag_name
