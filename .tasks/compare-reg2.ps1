$root = 'E:\1C\AY\BPLM-UHLM-XML'
$csvPath = (Get-ChildItem -LiteralPath $root -Filter '2*.csv' | Select-Object -First 1).FullName
$xmlPath = Join-Path $root 'BPLM-UH33LM_remix.xml'
$outPath = Join-Path $root '.tasks\compare-reg-result.txt'
$lines = Get-Content -LiteralPath $csvPath -Encoding UTF8
$names = New-Object System.Collections.Generic.List[string]
foreach ($line in $lines[1..($lines.Count-1)]) {
    if ($line.Trim()) { [void]$names.Add(($line -split ';')[2].Trim()) }
}
$pvd = Select-String -Path $xmlPath -Pattern '<[^>]+>[^<]*\.([^<]+)</[^>]+>' -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value }
$pvd = $pvd | Where-Object { $_ -notmatch '^[0-9]+$' } | Sort-Object -Unique
$pvdFiltered = Select-String -Path $xmlPath -Pattern 'RegistrSvedeniiZapis' -SimpleMatch
$pvd2 = Select-String -Path $xmlPath -Pattern 'RegistrSvedeniiZapis' -SimpleMatch
# fallback: extract by known prefix bytes in file
$text = Get-Content -LiteralPath $xmlPath -Encoding UTF8 -Raw
$prefix = [string][char]0x0420 + [char]0x0435 + [char]0x0433 + [char]0x0438 + [char]0x0441 + [char]0x0442 + [char]0x0440 + [char]0x0421 + [char]0x0432 + [char]0x0435 + [char]0x0434 + [char]0x0435 + [char]0x043D + [char]0x0438 + [char]0x0439 + [char]0x0417 + [char]0x0430 + [char]0x043F + [char]0x0438 + [char]0x0441 + [char]0x044C + '.'
$rx = [regex]::new('<[^>]+>' + [regex]::Escape($prefix) + '([^<]+)</[^>]+>')
$pvd = $rx.Matches($text) | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
$setPvd = [System.Collections.Generic.HashSet[string]]::new([string[]]$pvd)
$both = $names | Where-Object { $setPvd.Contains($_) } | Sort-Object
$csvNotPvd = $names | Where-Object { -not $setPvd.Contains($_) } | Sort-Object
$pvdNotCsv = $pvd | Where-Object { -not $names.Contains($_) } | Sort-Object
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("CSV count: $($names.Count)")
[void]$sb.AppendLine("PVD count: $($pvd.Count)")
[void]$sb.AppendLine("both: $($both.Count)")
[void]$sb.AppendLine("csv_not_pvd: $($csvNotPvd.Count)")
[void]$sb.AppendLine("pvd_not_csv: $($pvdNotCsv.Count)")
[void]$sb.AppendLine('--- BOTH ---')
$both | ForEach-Object { [void]$sb.AppendLine($_) }
[void]$sb.AppendLine('--- CSV NOT PVD ---')
$csvNotPvd | ForEach-Object { [void]$sb.AppendLine($_) }
[void]$sb.AppendLine('--- PVD NOT CSV ---')
$pvdNotCsv | ForEach-Object { [void]$sb.AppendLine($_) }
$sb.ToString() | Set-Content -LiteralPath $outPath -Encoding UTF8
Write-Output $outPath
