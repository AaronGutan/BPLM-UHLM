$csvFiles = Get-ChildItem -LiteralPath 'e:\1C\AY\BPLM-UHLM-XML' -Filter '2*.csv'
$csvPath = $csvFiles[0].FullName
$lines = Get-Content -LiteralPath $csvPath -Encoding UTF8
$regDir = 'e:\1C\AY\BPLM-UHLM-XML\acclmcopy\InformationRegisters'

$results = New-Object System.Collections.Generic.List[object]
$missingMeta = New-Object System.Collections.Generic.List[string]

foreach ($line in $lines[1..($lines.Length - 1)]) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $parts = $line.Split(';')
    if ($parts.Length -lt 3) { continue }
    $regName = $parts[2]
    $metaPath = Join-Path $regDir ($regName + '.xml')
    if (-not (Test-Path -LiteralPath $metaPath)) {
        [void]$missingMeta.Add($regName)
        continue
    }
    $xmlText = Get-Content -LiteralPath $metaPath -Encoding UTF8 -Raw
    $writeMode = $null
    $periodicity = $null
    if ($xmlText -match '<WriteMode>([^<]+)</WriteMode>') {
        $writeMode = $matches[1]
    }
    if ($xmlText -match '<InformationRegisterPeriodicity>([^<]+)</InformationRegisterPeriodicity>') {
        $periodicity = $matches[1]
    }
    $results.Add([pscustomobject]@{
        Line = $line
        Name = $regName
        WriteMode = $writeMode
        Periodicity = $periodicity
        MetaPath = $metaPath
    })
}

$independent = $results | Where-Object { $_.WriteMode -eq 'Independent' }
$dependent = $results | Where-Object { $_.WriteMode -ne 'Independent' }

$outPath = 'e:\1C\AY\BPLM-UHLM-XML\.tasks\final-independent-reg-analysis.txt'
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('CSV=' + $csvPath)
[void]$sb.AppendLine('TOTAL=' + $results.Count)
[void]$sb.AppendLine('INDEPENDENT=' + $independent.Count)
[void]$sb.AppendLine('DEPENDENT=' + $dependent.Count)
[void]$sb.AppendLine('MISSING_META=' + $missingMeta.Count)
[void]$sb.AppendLine('--- INDEPENDENT ---')
foreach ($item in $independent) {
    [void]$sb.AppendLine($item.Name + '|' + $item.WriteMode + '|' + $item.Periodicity)
}
[void]$sb.AppendLine('--- DEPENDENT ---')
foreach ($item in $dependent) {
    [void]$sb.AppendLine($item.Name + '|' + $item.WriteMode + '|' + $item.Periodicity + '|' + $item.MetaPath)
}
if ($missingMeta.Count -gt 0) {
    [void]$sb.AppendLine('--- MISSING ---')
    foreach ($n in $missingMeta) {
        [void]$sb.AppendLine($n)
    }
}

$csvOut = @($lines[0])
foreach ($item in $independent) {
    $csvOut += $item.Line
}
$csvOutPath = 'e:\1C\AY\BPLM-UHLM-XML\.tasks\final-independent-reg-csv.txt'
$csvOut | Set-Content -LiteralPath $csvOutPath -Encoding UTF8
$sb.ToString() | Set-Content -LiteralPath $outPath -Encoding UTF8

Write-Output ('total=' + $results.Count)
Write-Output ('independent=' + $independent.Count)
Write-Output ('dependent=' + $dependent.Count)
Write-Output ('missing=' + $missingMeta.Count)
