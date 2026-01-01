$dequeHpp = './deque/deque.hpp'

$c1 = Get-Content -LiteralPath './patches/inc/deque1' -Raw
$c2 = Get-Content -LiteralPath $dequeHpp -Raw
$c3 = Get-Content -LiteralPath './patches/inc/deque3' -Raw

$i1 = $c2.IndexOf("`n",$c2.IndexOf('// STL-vNext BEGIN')) + 1
$i2 = $c2.LastIndexOf("`n",$c2.IndexOf('// STL-vNext END'))

$c2 = $c2.Substring($i1, $i2-$i1)

# $c2 = $c2.Replace('    template < _RANGES input_range _Ry> // _Container_compatible_range<_Ty>', '    template < _Container_compatible_range<_Ty> _Ry>')

$c1 + $c2 + $c3 | Set-Content './patches/inc/deque' -Enc UTF8 -NoNewline