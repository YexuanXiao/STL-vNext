param(
    [string]$repoPath = "..\"
)

class TextFile {
    [string[]]$Lines
    [string]$FilePath

    TextFile([string]$filePath) {
        $this.FilePath = $filePath
        if (Test-Path $this.FilePath) {
            $this.Lines = Get-Content -Path $this.FilePath -Encoding utf8NoBOM
        }
        else {
            throw "File '$filePath' not found"
        }
    }

    [void] Backup([string]$filePath) {
        $parent = Split-Path $filePath -Parent
        if (!(Test-Path $parent)) {
            New-Item -ItemType Directory $parent -Force
        }
        Copy-Item $this.FilePath $filePath -Force
    }

    [void] Save() {
        $this.Lines | Out-File -FilePath $this.FilePath -Encoding utf8NoBOM
    }

    [int] Find([string]$pattern) {
        $indices = @()

        for ($i = 0; $i -lt $this.Lines.Count; $i++) {
            if ($this.Lines[$i].Contains($pattern)) {
                $indices += $i
            }
        }

        if ($indices.Count -eq 0) {
            throw "Pattern '$pattern' not found in file"
        }
        elseif ($indices.Count -gt 1) {
            throw "Pattern '$pattern' found at multiple positions: $($indices -join ', ')"
        }

        return $indices[0]
    }

    [int] FindMultiLine([string[]]$patternLines) {
        $result = @()
        $lenA = $this.Lines.Length
        $lenB = $patternLines.Length

        if ($lenB -eq 0) {
            throw "Pattern lines cannot be empty"
        }

        if ($lenA -lt $lenB) {
            throw "Pattern lines count ($($lenB)) exceeds file lines count ($($lenA))"
        }

        for ($i = 0; $i -le $lenA - $lenB; $i++) {
            $match = $true

            for ($j = 0; $j -lt $lenB; $j++) {
                if (-not $this.Lines[$i + $j].Contains($patternLines[$j])) {
                    $match = $false
                    break
                }
            }

            if ($match) {
                $result += $i
            }
        }

        if ($result.Count -eq 0) {
            throw "Multi-line pattern not found in file"
        }
        elseif ($result.Count -gt 1) {
            throw "Found multi match results: $($result -join ', ')"
        }

        return $result[0]
    }

    [void] Insert([int]$index, [string]$line) {
        if ($index -lt 0 -or $index -gt $this.Lines.Count) {
            throw "Index $index out of range [0, $($this.Lines.Count)]"
        }

        $newLines = @()
        if ($index -eq 0) {
            $newLines = @($line) + $this.Lines
        }
        elseif ($index -eq $this.Lines.Count) {
            $newLines = $this.Lines + @($line)
        }
        else {
            $newLines = $this.Lines[0..($index - 1)] + @($line) + $this.Lines[$index..($this.Lines.Count - 1)]
        }
        $this.Lines = $newLines
    }

    [void] InsertRange([int]$index, [string[]]$lines) {
        if ($index -lt 0 -or $index -gt $this.Lines.Count) {
            throw "Index $index out of range [0, $($this.Lines.Count)]"
        }

        if ($lines.Count -eq 0) {
            throw "Lines is empty"
        }

        $newLines = @()
        if ($index -eq 0) {
            $newLines = $lines + $this.Lines
        }
        elseif ($index -eq $this.Lines.Count) {
            $newLines = $this.Lines + $lines
        }
        else {
            $newLines = $this.Lines[0..($index - 1)] + $lines + $this.Lines[$index..($this.Lines.Count - 1)]
        }
        $this.Lines = $newLines
    }

    [void] Append([string]$line) {
        $this.Insert($this.Lines.Count, $line)
    }

    [void] AppendRange([string[]]$lines) {
        $this.InsertRange($this.Lines.Count, $lines)
    }

    [void] Remove([int]$index) {
        if ($index -lt 0 -or $index -ge $this.Lines.Count) {
            throw "Index $index out of range [0, $($this.Lines.Count-1)]"
        }
        $this.Lines = $this.Lines | Select-Object -Index (0..($this.Lines.Count - 1) | Where-Object { $_ -ne $index })
    }

    [void] RemoveRange([int]$startIndex, [int]$endIndex) {
        if ($startIndex -lt 0 -or $endIndex -ge $this.Lines.Count -or $startIndex -gt $endIndex) {
            throw "Invalid range [$startIndex, $endIndex]"
        }

        $indicesToRemove = $startIndex..$endIndex
        $this.Lines = $this.Lines | Select-Object -Index (0..($this.Lines.Count - 1) | Where-Object { $_ -notin $indicesToRemove })
    }

    [void] Replace([int]$index, [string]$newContent) {
        if ($index -lt 0 -or $index -ge $this.Lines.Count) {
            throw "Index $index out of range [0, $($this.Lines.Count-1)]"
        }
        $this.Lines[$index] = $newContent
    }

    [void] ReplaceRange([int]$startIndex, [int]$endIndex, [string[]]$lines) {
        $this.RemoveRange($startIndex, $endIndex);
        $this.InsertRange($startIndex, $lines);
    }

    [int] Count() {
        return $this.Lines.Count
    }

    [string[]] GetLines() {
        return $this.Lines.Clone()
    }
}

$vNextPath = $PSScriptRoot

$backupPath = Join-Path $vNextPath "backup"
$patchesPath = Join-Path $vNextPath "patches"

if (Test-Path $backupPath) {
    throw "Backup path '$backupPath' is exist"
}

New-Item -Path $backupPath -ItemType Directory > $null

# Boost.Math

& {
    $stlCMakeLists = [TextFile]::new((Join-Path $repoPath 'stl\CMakeLists.txt'))
    $stlCMakeLists.Backup((Join-Path $backupPath 'stl\CMakeLists.txt'))
    $line = $stlCMakeLists.Find('set_target_properties(libcpmt${FLAVOR_SUFFIX} PROPERTIES STATIC_LIBRARY_OPTIONS "${VCLIBS_EXPLICIT_MACHINE}")')
    $content = '    add_custom_command(TARGET libcpmt${FLAVOR_SUFFIX} POST_BUILD COMMAND powershell ${CMAKE_SOURCE_DIR}/FixSpecialMath.ps1 "$<TARGET_FILE:libcpmt${FLAVOR_SUFFIX}>" VERBATIM)'
    $stlCMakeLists.Insert($line + 1, $content)
    $stlCMakeLists.Save()
    Copy-Item (Join-Path $patchesPath 'FixSpecialMath.ps1') (Join-Path $repoPath 'FixSpecialmath.ps1')
}

# array

& {
    $array = [TextFile]::new((Join-Path $repoPath 'stl\inc\array'))
    $array.Backup((Join-Path $backupPath 'stl\inc\array'))
    $arrayPatch = [TextFile]::new((Join-Path $patchesPath 'inc\array'))
    $pattern = @(
        'conditional_t<disjunction_v<is_default_constructible<_Ty>, _Is_implicitly_default_constructible<_Ty>>, _Ty,',
        '_Empty_array_element>',
        '_Elems[1]{};')
    $idx = $array.FindMultiLine($pattern)
    $array.ReplaceRange($idx, $idx + $pattern.Count, $arrayPatch.GetLines())
    $array.Save()
}

# deque

& {
    Copy-Item -Path (Join-Path $repoPath 'stl\inc\deque') -Destination (Join-Path $backupPath 'stl\inc\deque')
    Copy-Item -Path (Join-Path $patchesPath 'inc\deque') -Destination (Join-Path $repoPath 'stl\inc\deque') -Force
}

<#

#string

& {
    Copy-Item -Path (Join-Path $repoPath 'stl\inc\xstring') -Destination (Join-Path $backupPath 'stl\inc\xstring')
    Copy-Item -Path (Join-Path $patchesPath 'inc\xstring') -Destination (Join-Path $repoPath 'stl\inc\xstring') -Force
}

& {
    $expected = [TextFile]::new((Join-Path $repoPath 'tests\libcxx\expected_results.txt'))
    $expected.Backup((Join-Path $backupPath 'tests\libcxx\expected_results.txt'))
    $expectedPatch = [TextFile]::new((Join-Path $patchesPath 'expected_results.txt'))
    $expected.AppendRange($expectedPatch.GetLines())
    $expected.Save()
}

& {
    $fs = [TextFile]::new((Join-Path $repoPath 'stl\inc\filesystem'))
    $fs.Backup((Join-Path $backupPath 'stl\inc\filesystem'))
    $fsPatch1 = [TextFile]::new((Join-Path $patchesPath 'inc\filesystem1'))
    $fsPatch2 = [TextFile]::new((Join-Path $patchesPath 'inc\filesystem2'))
    $pattern = @(
        '#if _HAS_CXX20',
        '_NODISCARD friend strong_ordering operator<=>(const path& _Left, const path& _Right) noexcept {',
        'return _Left.compare(_Right._Text) <=> 0;',
        '}')
    $fs.InsertRange($fs.FindMultiLine($pattern), $fsPatch1.GetLines())
    $fs.InsertRange($fs.FindMultiLine($pattern) + $pattern.Count, $fsPatch2.GetLines())
    $fs.Save()
}

#>

# tests

& {
    $sourceFolder = Join-Path $repoPath 'tests\std\tests'
    $backupFolder = Join-Path $backupPath 'tests\std\tests'
    $std14 = 'c++14'
    $std17 = 'c++17'

    if (!(Test-Path $backupFolder)) {
        New-Item -Path $backupFolder -ItemType Directory -Force > $null
    }

    $lstFiles = Get-ChildItem -Path $sourceFolder -Filter "*.lst" -File

    if ($lstFiles.Count -eq 0) {
        throw "Error path: '$sourceFolder'"
    }

    foreach ($file in $lstFiles) {
        $backupPath = Join-Path $backupFolder $file.Name

        $content = Get-Content -Path $file.FullName -Encoding UTF8

        $filteredContent = $content | Where-Object {
            !($_.Contains($std14) -or $_.Contains($std17))
        }

        if ($filteredContent.Count -eq $content.Count) {
            continue
        }

        Copy-Item -Path $file.FullName -Destination $backupPath
        $filteredContent | Out-File -FilePath $file.FullName -Encoding UTF8
    }
}

# deque array tests

& {
    Copy-Item (Join-Path $patchesPath 'GH_001036_vector_deque_move_only') (Join-Path $repoPath 'tests\std\tests\GH_001036_vector_deque_move_only') -Force -Recurse
    Copy-Item (Join-Path $patchesPath 'GH_005583_array_T_0') (Join-Path $repoPath 'tests\std\tests\GH_005583_array_T_0') -Force -Recurse
    Copy-Item (Join-Path $patchesPath 'LLVM_062056_deque_exception_safety') (Join-Path $repoPath 'tests\std\tests\LLVM_062056_deque_exception_safety') -Force -Recurse
}

& {
    $testLst = [TextFile]::new((Join-Path $repoPath 'tests\std\test.lst'))
    $testLst.Backup((Join-Path $backupPath 'tests\std\test.lst'))
    $testLst.Insert($testLst.Find('tests\GH_001017_discrete_distribution_out_of_range') + 1, 'tests\GH_001036_vector_deque_move_only')
    $testLst.Insert($testLst.Find('tests\LWG2381_num_get_floating_point'), 'tests\LLVM_062056_deque_exception_safety')
    $testLst.Insert($testLst.Find('tests\GH_005553_regex_character_translation') + 1, 'tests\GH_005583_array_T_0')
    $testLst.Save()
}
