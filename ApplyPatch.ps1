param(
    [string]$repoPath = "..\"
)

$enable_array = $true
<#
$enable_string = $false
#>
$enable_deque = $true
$enable_math = $true

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

if ($enable_math) {
    $base = 'stl\CMakeLists.txt'
    $stlCMakeLists = [TextFile]::new((Join-Path $repoPath $base))
    $stlCMakeLists.Backup((Join-Path $backupPath $base))
    $line = $stlCMakeLists.Find('set_target_properties(libcpmt${FLAVOR_SUFFIX} PROPERTIES STATIC_LIBRARY_OPTIONS "${VCLIBS_EXPLICIT_MACHINE}")')
    $content = '    add_custom_command(TARGET libcpmt${FLAVOR_SUFFIX} POST_BUILD COMMAND powershell ${CMAKE_SOURCE_DIR}/FixSpecialMath.ps1 "$<TARGET_FILE:libcpmt${FLAVOR_SUFFIX}>" VERBATIM)'
    $stlCMakeLists.Insert($line + 1, $content)
    $stlCMakeLists.Save()
    Copy-Item (Join-Path $patchesPath 'FixSpecialMath.ps1') (Join-Path $repoPath 'FixSpecialMath.ps1')
}

# array

if ($enable_array) {
    $base = 'stl\inc\array'
    $array = [TextFile]::new((Join-Path $repoPath $base))
    $array.Backup((Join-Path $backupPath $base))
    $arrayPatch = [TextFile]::new((Join-Path $patchesPath 'inc\array'))
    $pattern = @(
        'conditional_t<disjunction_v<is_default_constructible<_Ty>, _Is_implicitly_default_constructible<_Ty>>, _Ty,',
        '_Empty_array_element>',
        '_Elems[1]{};')
    $idx = $array.FindMultiLine($pattern)
    $array.ReplaceRange($idx, $idx + $pattern.Count, $arrayPatch.GetLines())
    $array.Save()

    Copy-Item (Join-Path $patchesPath 'GH_005583_array_T_0') (Join-Path $repoPath 'tests\std\tests\') -Force -Recurse
}

if ($enable_array) {
    $base = 'tests\std\tests\Dev11_1074023_constexpr\test.cpp'
    $test = [TextFile]::new((Join-Path $repoPath $base))
    $test.Backup((Join-Path $backupPath $base))
    $test.Insert($test.Find('constexpr array<int, 0> empty_array;'), "#pragma warning( push )`n#pragma warning( disable : 4268 )")
    $test.Insert($test.Find('constexpr array<int, 0> empty_array;') + 1, '#pragma warning( pop )')
    $test.Save()
}

if ($enable_array) {
    $base = 'tests\std\tests\P2321R2_views_adjacent\test.cpp'
    $test = [TextFile]::new((Join-Path $repoPath $base))
    $test.Backup((Join-Path $backupPath $base))
    $test.Insert($test.Find('constexpr array<repeated_tuple<int, 7>, 0> adjacent7_result;'), "#pragma warning( push )`n#pragma warning( disable : 4268 )")
    $test.Insert($test.Find('constexpr array<repeated_tuple<int, 7>, 0> adjacent7_result;') + 1, '#pragma warning( pop )')
    $test.Save()
}

# disable by BUG 1
if ($enable_array -and $false) {
    $base = 'tests\libcxx\expected_results.txt'
    $expectedRes = [TextFile]::new((Join-Path $repoPath $base))
    $expectedRes.Backup((Join-Path $backupPath $base))
    $expectedRes.Remove($exPectedRes.Find('std/containers/sequences/array/array.cons/implicit_copy.pass.cpp FAIL'))
    $expectedRes.Insert($exPectedRes.Find('# Bogus test believes that copyability of array<T, 0> must be the same as array<T, 1>'), '# Fixed by YexuanXiao/STL-vNext')
    $expectedRes.Save()
}

# deque

if ($enable_deque) {
    Copy-Item -Path (Join-Path $repoPath 'stl\inc\deque') -Destination (Join-Path $backupPath 'stl\inc\deque')
    Copy-Item -Path (Join-Path $patchesPath 'inc\deque') -Destination (Join-Path $repoPath 'stl\inc\deque') -Force
    Copy-Item (Join-Path $patchesPath 'GH_001036_vector_deque_move_only') (Join-Path $repoPath 'tests\std\tests\') -Force -Recurse
    Copy-Item (Join-Path $patchesPath 'LLVM_062056_deque_exception_safety') (Join-Path $repoPath 'tests\std\tests\') -Force -Recurse
}

if ($enable_deque) {
    $base = 'tests\std\tests\GH_003570_allocate_at_least\test.cpp'
    $atLeast = [TextFile]::new((Join-Path $repoPath $base))
    $atLeast.Backup((Join-Path $backupPath $base))
    $atLeast.Remove($atLeast.Find('    test_deque();'))
    $atLeast.Save()
}

if ($enable_deque) {
    $base = 'tests\std\tests\GH_005315_destructor_tombstones\test.cpp'
    $asanDestructor = [TextFile]::new((Join-Path $repoPath $base))
    $asanDestructor.Backup((Join-Path $backupPath $base))
    $asanDestructor.Remove($asanDestructor.Find('        test_deque,'))
    $asanDestructor.Save()
}

if ($enable_deque) {
    $base = 'tests\std\tests\Dev10_500860_overloaded_address_of\test.cpp'
    $overAddrOf = [TextFile]::new((Join-Path $repoPath $base))
    $overAddrOf.Backup((Join-Path $backupPath $base))
    $overAddrOf.Replace($overAddrOf.Find('template class std::_Deque_iterator<_Deque_val<_Deque_simple_types<Evil>>>;'), 'template class std::__deque_detail::__deque_iterator<__deque_detail::__add_adl_firewall_t<Evil>, __deque_detail::__add_adl_firewall_t<Evil*>, std::ptrdiff_t>;')
    $overAddrOf.Replace($overAddrOf.Find('template class std::_Deque_const_iterator<_Deque_val<_Deque_simple_types<Evil>>>;'), 'template class std::__deque_detail::__deque_iterator<__deque_detail::__add_adl_firewall_t<const Evil>, __deque_detail::__add_adl_firewall_t<Evil*>, std::ptrdiff_t>;')
    $overAddrOf.Remove($overAddrOf.Find('template class std::_Deque_unchecked_iterator<_Deque_val<_Deque_simple_types<Evil>>>;'))
    $overAddrOf.Remove($overAddrOf.Find('template class std::_Deque_unchecked_const_iterator<_Deque_val<_Deque_simple_types<Evil>>>;'))
    $overAddrOf.Save()
}

if ($enable_deque) {
    $base = 'tests\std\tests\GH_005090_stl_hardening\test.cpp'
    $harden = [TextFile]::new((Join-Path $repoPath $base))
    $harden.Backup((Join-Path $backupPath $base))
    $harden.Remove($harden.Find('        test_deque_subscript,'))
    $harden.Remove($harden.Find('        test_deque_subscript_const,'))
    $harden.Remove($harden.Find('        test_deque_front,'))
    $harden.Remove($harden.Find('        test_deque_front_const,'))
    $harden.Remove($harden.Find('        test_deque_back,'))
    $harden.Remove($harden.Find('        test_deque_back_const,'))
    $harden.Remove($harden.Find('        test_deque_pop_front,'))
    $harden.Remove($harden.Find('        test_deque_pop_back,'))
    $harden.Save()
}

if ($enable_deque) {
    $base = 'tests\std\tests\VSO_0102478_moving_allocators\test.cpp'
    $debug_begin = [TextFile]::new((Join-Path $repoPath $base))
    $debug_begin.Backup((Join-Path $backupPath $base))
    $debug_begin.Remove($debug_begin.Find('container_test<deque>();'))
    $debug_begin.Save()
}

if ($enable_deque) {
    $base = 'tests\std\tests\VSO_0429900_fast_debug_range_based_for\test.cpp'
    $debug_begin = [TextFile]::new((Join-Path $repoPath $base))
    $debug_begin.Backup((Join-Path $backupPath $base))
    $debug_begin.Remove($debug_begin.Find('test_case_sequence_container<deque>();'))
    $debug_begin.Save()
}

if ($enable_deque) {
    $base = 'tests\std\tests\GH_002992_unwrappable_iter_sent_pairs\test.compile.pass.cpp'
    $unwrap_iter = [TextFile]::new((Join-Path $repoPath $base))
    $unwrap_iter.Backup((Join-Path $backupPath $base))
    $unwrap_iter.Remove($unwrap_iter.Find('test_classic_range<deque<int>>();'))
    $unwrap_iter.Save()
}

if ($enable_deque) {
    $base = 'tests\std\tests\VSO_0830211_container_debugging_range_checks\test.cpp'
    $debug_range = [TextFile]::new((Join-Path $repoPath $base))
    $debug_range.Backup((Join-Path $backupPath $base))
    $debug_range.Remove($debug_range.Find('TestCases<DequeTestCaseTraits>::negative_cases();'))
    $debug_range.Remove($debug_range.Find('TestCases<ConstDequeTestCaseTraits>::negative_cases();'))
    $debug_range.Remove($debug_range.Find('TestCases<DequeTestCaseTraits>::add_cases(exec);'))
    $debug_range.Remove($debug_range.Find('TestCases<ConstDequeTestCaseTraits>::add_cases(exec);'))
    $debug_range.Save()
}

if ($enable_deque -or $enable_array) {
    $base = 'tests\std\test.lst'
    $testLst = [TextFile]::new((Join-Path $repoPath $base))
    $testLst.Backup((Join-Path $backupPath $base))
    if ($enable_deque) {
        $testLst.Insert($testLst.Find('tests\GH_001017_discrete_distribution_out_of_range') + 1, 'tests\GH_001036_vector_deque_move_only')
        $testLst.Insert($testLst.Find('tests\LWG2381_num_get_floating_point'), 'tests\LLVM_062056_deque_exception_safety')
    }
    if ($enable_array) {
        $testLst.Insert($testLst.Find('tests\GH_005553_regex_character_translation') + 1, 'tests\GH_005583_array_T_0')
    }
    $testLst.Save()
}

if ($enable_deque) {
    $base = 'tests\std\expected_results.txt'
    $stdE = [TextFile]::new((Join-Path $repoPath $base))
    $stdE.Backup((Join-Path $backupPath $base))
    $stdE.Append('tests/Dev10_709168_marking_iterators_as_checked SKIPPED')
    $stdE.Append('GH_002992_unwrappable_iter_sent_pairs SKIPPED')
    $stdE.Save()
}

if ($enable_deque) {
    $base = 'tests\std\include\input_iterator.hpp'
    $iit = [TextFile]::new((Join-Path $repoPath $base))
    $iit.Backup((Join-Path $backupPath $base))

    $content = Get-Content -Path $iit.FilePath -Raw -Encoding utf8NoBOM

    if (($newText = $content -replace 'void operator\+\+\(int\) = delete; // avoid postincrement', 'void operator++(int) { std::abort(); } // avoid postincrement') -eq $content) {
        throw 'Pattern not found in file'
    } else {
        $newText | Out-File -FilePath $iit.FilePath -Encoding utf8NoBOM
    }
}

<#

#string

if ($enable_string) {
    Copy-Item -Path (Join-Path $repoPath 'stl\inc\xstring') -Destination (Join-Path $backupPath 'stl\inc\xstring')
    Copy-Item -Path (Join-Path $patchesPath 'inc\xstring') -Destination (Join-Path $repoPath 'stl\inc\xstring') -Force
}

if ($enable_string) {
    $expected = [TextFile]::new((Join-Path $repoPath 'tests\libcxx\expected_results.txt'))
    $expected.Backup((Join-Path $backupPath 'tests\libcxx\expected_results.txt'))
    $expectedPatch = [TextFile]::new((Join-Path $patchesPath 'expected_results.txt'))
    $expected.AppendRange($expectedPatch.GetLines())
    $expected.Save()
}

if ($enable_string) {
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

# disable tests for C++14 and C++17

& {
    $base = 'tests'
    $sourceFolder = Join-Path $repoPath $base
    $backupFolder = Join-Path $backupPath $base
    $std14 = 'c++14'
    $std17 = 'c++17'

    if (!(Test-Path $backupFolder)) {
        New-Item -Path $backupFolder -ItemType Directory -Force > $null
    }

    $lstFiles = Get-ChildItem -Path $sourceFolder -Filter "*.lst" -File -Recurse

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