param(
    [string]$repoPath = "..\"
)

$backupPath = Join-Path $PSScriptRoot 'backup'

if (!(Test-Path $backupPath)) {
    throw 'Backup is not exist'
}

Copy-Item (Join-Path $backupPath '*') $repoPath -Force -Recurse
Remove-Item (Join-Path $repoPath 'tests\std\tests\GH_001036_vector_deque_move_only') -Force -Recurse
Remove-Item (Join-Path $repoPath 'tests\std\tests\GH_005583_array_T_0') -Force -Recurse
Remove-Item (Join-Path $repoPath 'tests\std\tests\LLVM_062056_deque_exception_safety') -Force -Recurse
Remove-Item (Join-Path $repoPath 'FixSpecialMath.ps1') -Force
