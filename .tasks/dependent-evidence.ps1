$analysis = Get-Content -LiteralPath 'e:\1C\AY\BPLM-UHLM-XML\.tasks\final-independent-reg-analysis.txt' -Encoding UTF8
$inDep = $false
$sb = New-Object System.Text.StringBuilder
foreach ($line in $analysis) {
    if ($line -eq '--- DEPENDENT ---') { $inDep = $true; continue }
    if (-not $inDep) { continue }
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $parts = $line.Split('|')
    if ($parts.Length -lt 4) { continue }
    $name = $parts[0]
    $path = $parts[3]
    $lineNo = 0
    $writeLine = ''
    $periodLine = ''
    Get-Content -LiteralPath $path -Encoding UTF8 | ForEach-Object {
        $lineNo++
        if ($_ -match '<WriteMode>') { $writeLine = $lineNo.ToString() + ':' + $_.Trim() }
        if ($_ -match '<InformationRegisterPeriodicity>') { $periodLine = $lineNo.ToString() + ':' + $_.Trim() }
    }
    [void]$sb.AppendLine($name + '|' + $writeLine + '|' + $periodLine)
}
$sb.ToString() | Set-Content -LiteralPath 'e:\1C\AY\BPLM-UHLM-XML\.tasks\dependent-reg-evidence.txt' -Encoding UTF8
Write-Output 'done'
