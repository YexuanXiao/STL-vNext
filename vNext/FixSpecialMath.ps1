param(
    [Parameter(Mandatory = $true)]
    [string]$LibPath
)

function Update-LibrarySymbols {
        param(
        [Parameter(Mandatory=$true)]
        [string]$LibPath
    )

    $RawNS = "@boost"
    $NewNS = "@_Boost"

    $tempRulesFile = Join-Path (Split-Path $LibPath -Parent) "temp_rules.txt"

    $symbols = llvm-nm -j $LibPath

    $rules = @()

    foreach ($symbol in $symbols) {
        if ($symbol.Contains($RawNS)) {
            $newSymbol = $symbol.Replace($RawNS, $NewNS)
            $rules += "$symbol $newSymbol"
        }
    }

    if ($rules.Count -gt 0) {
        Set-Content -Path $tempRulesFile -Value $rules
        llvm-objcopy --redefine-syms $tempRulesFile $LibPath
        Remove-Item $tempRulesFile
    }
}

function Exact-Update-Repack {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LibPath
    )
    $libDirectory = Split-Path $LibPath -Parent
    $filename = Split-Path -Path $LibPath -Leaf
    $tempDir = Join-Path $libDirectory ($filename + "_temp")
    Write-Host $tempDir
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    & llvm-ar x $LibPath --output $tempDir
    $specialMathLib = Join-Path $tempDir "special_math.cpp.obj"
    Update-LibrarySymbols $specialMathLib
    & llvm-ar rcs $LibPath (Get-ChildItem $tempDir -File | ForEach-Object { $_.FullName })
    Remove-Item $tempDir -Recurse -Force
}

Exact-Update-Repack $LibPath
