$root = 'E:\1C\AY\BPLM-UHLM-XML'
$csvPath = (Get-ChildItem -LiteralPath $root -Filter '2*.csv' | Select-Object -First 1).FullName
$removePath = Join-Path $root '.tasks\remove-reg-names.txt'
$outPath = Join-Path $root '.tasks\keep-reg-lines.txt'
$remove = Get-Content -LiteralPath $removePath -Encoding UTF8 | Where-Object { $_.Trim() } | ForEach-Object { $_.Trim() }
$removeSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$remove)
$lines = Get-Content -LiteralPath $csvPath -Encoding UTF8
$header = $lines[0]
$keep = New-Object System.Collections.Generic.List[string]
foreach ($line in $lines[1..($lines.Count-1)]) {
    if (-not $line.Trim()) { continue }
    $name = ($line -split ';')[2].Trim()
    if (-not $removeSet.Contains($name)) { [void]$keep.Add($line) }
}
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine($header)
$keep | ForEach-Object { [void]$sb.AppendLine($_) }
[void]$sb.AppendLine('')
[void]$sb.AppendLine("KEEP_COUNT=$($keep.Count)")
[void]$sb.AppendLine("REMOVE_COUNT=$($removeSet.Count)")
$sb.ToString() | Set-Content -LiteralPath $outPath -Encoding UTF8
Write-Output $outPath
