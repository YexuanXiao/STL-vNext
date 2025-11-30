param(
    [string]$repoPath = "..\"
)

Remove-Item (Join-Path $repoPath 'vNext\backup') -Force -Recurse
