$include = Get-Content -LiteralPath 'e:\1C\AY\BPLM-UHLM-XML\.tasks\include-reg-names.txt' -Encoding UTF8 | Where-Object { $_.Trim() -ne '' }
$includeSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($n in $include) {
    [void]$includeSet.Add($n)
}

$csvFiles = Get-ChildItem -LiteralPath 'e:\1C\AY\BPLM-UHLM-XML' -Filter '2*.csv'
$csvPath = $csvFiles[0].FullName
$lines = Get-Content -LiteralPath $csvPath -Encoding UTF8
$out = @($lines[0])
foreach ($line in $lines[1..($lines.Length - 1)]) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $parts = $line.Split(';')
    if ($parts.Length -ge 3) {
        $regName = $parts[2]
        if ($includeSet.Contains($regName)) {
            $out += $line
        }
    }
}

$outPath = 'e:\1C\AY\BPLM-UHLM-XML\.tasks\final-include-reg-csv.txt'
$out | Set-Content -LiteralPath $outPath -Encoding UTF8

Write-Output ('csv=' + $csvPath)
Write-Output ('include_names=' + $include.Count)
Write-Output ('data_rows=' + ($out.Count - 1))

$foundSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($line in $out[1..($out.Count - 1)]) {
    $parts = $line.Split(';')
    if ($parts.Length -ge 3) {
        [void]$foundSet.Add($parts[2])
    }
}

$missing = @()
foreach ($n in $include) {
    if (-not $foundSet.Contains($n)) {
        $missing += $n
    }
}

if ($missing.Count -gt 0) {
    Write-Output 'MISSING:'
    $missing
} else {
    Write-Output 'all_names_found_in_csv'
}
