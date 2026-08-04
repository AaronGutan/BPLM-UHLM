$csvPath = Join-Path $PSScriptRoot '..\2список игнорируемых регистров сведений при синхронизации по метаданным УХ.csv'
$xmlPath = Join-Path $PSScriptRoot '..\BPLM-UH33LM_remix.xml'

$lines = Get-Content -LiteralPath $csvPath -Encoding UTF8
$names = @()
foreach ($line in $lines[1..($lines.Count-1)]) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $parts = $line -split ';'
    if ($parts.Count -ge 3) { $names += $parts[2].Trim() }
}

$xml = [xml](Get-Content -LiteralPath $xmlPath -Encoding UTF8)
$rules = $xml.SelectNodes("//ПравилаВыгрузкиДанных//Группа[Код='РегистрыСведений']/Правило")
$pvdNames = @()
foreach ($r in $rules) { $pvdNames += $r.Код.Trim() }
$pvdNames = $pvdNames | Sort-Object -Unique

$inBoth = $names | Where-Object { $pvdNames -contains $_ }
$inCsvNotPvd = $names | Where-Object { $pvdNames -notcontains $_ }
$inPvdNotCsv = $pvdNames | Where-Object { $names -notcontains $_ }

"CSV count: $($names.Count)"
"PVD rules count: $($pvdNames.Count)"
"In CSV and PVD: $($inBoth.Count)"
"In CSV not PVD: $($inCsvNotPvd.Count)"
"In PVD not CSV: $($inPvdNotCsv.Count)"
'--- IN CSV AND PVD ---'
$inBoth
'--- IN CSV NOT PVD ---'
$inCsvNotPvd
'--- IN PVD NOT CSV ---'
$inPvdNotCsv
