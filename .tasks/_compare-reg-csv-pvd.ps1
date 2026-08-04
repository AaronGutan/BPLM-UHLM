# Compare CSV ignore list with remix PVD rules for information registers
$csvPath = 'E:\1C\AY\BPLM-UHLM-XML\2список игнорируемых регистров сведений при синхронизации по метаданным УХ.csv'
$xmlPath = 'E:\1C\AY\BPLM-UHLM-XML\BPLM-UH33LM_remix.xml'

$lines = Get-Content $csvPath -Encoding UTF8
$names = @()
foreach ($line in $lines[1..($lines.Count-1)]) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $parts = $line -split ';'
    if ($parts.Count -ge 3) { $names += $parts[2].Trim() }
}

$xml = [xml](Get-Content $xmlPath -Encoding UTF8)
$ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
$rules = $xml.SelectNodes('//ПравилаВыгрузкиДанных//Группа[Код="РегистрыСведений"]/Правило')
$pvdNames = @()
foreach ($r in $rules) { $pvdNames += $r.Код.Trim() }
$pvdNames = $pvdNames | Sort-Object -Unique

$inBoth = $names | Where-Object { $pvdNames -contains $_ }
$inCsvNotPvd = $names | Where-Object { $pvdNames -notcontains $_ }
$inPvdNotCsv = $pvdNames | Where-Object { $names -notcontains $_ }

Write-Output "CSV count: $($names.Count)"
Write-Output "PVD rules count: $($pvdNames.Count)"
Write-Output "In CSV and PVD: $($inBoth.Count)"
Write-Output "In CSV not PVD: $($inCsvNotPvd.Count)"
Write-Output "In PVD not CSV: $($inPvdNotCsv.Count)"
Write-Output '--- IN CSV AND PVD ---'
$inBoth | ForEach-Object { Write-Output $_ }
Write-Output '--- IN PVD NOT CSV (first 50) ---'
$inPvdNotCsv | Select-Object -First 50 | ForEach-Object { Write-Output $_ }
