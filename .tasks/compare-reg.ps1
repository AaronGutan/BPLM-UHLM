$root = Split-Path -Parent $PSScriptRoot
$csvPath = Get-ChildItem -LiteralPath $root -Filter '2*' | Where-Object { $_.Extension -eq '.csv' -and $_.Name -like '*регистр*' } | Select-Object -First 1 -ExpandProperty FullName
$xmlPath = Join-Path $root 'BPLM-UH33LM_remix.xml'
$lines = Get-Content -LiteralPath $csvPath -Encoding UTF8
$names = @()
foreach ($line in $lines[1..($lines.Count-1)]) {
    if ($line.Trim()) { $names += ($line -split ';')[2].Trim() }
}
$text = Get-Content -LiteralPath $xmlPath -Encoding UTF8 -Raw
$marker = [char]0x0420 + [char]0x0435 + [char]0x0433 + [char]0x0438 + [char]0x0441 + [char]0x0442 + [char]0x0440 + [char]0x044B + [char]0x0421 + [char]0x0432 + [char]0x0435 + [char]0x0434 + [char]0x0435 + [char]0x043D + [char]0x0438 + [char]0x0439
$startTag = '<' + [char]0x041A + [char]0x043E + [char]0x0434 + '>' + $marker + '</' + [char]0x041A + [char]0x043E + [char]0x0434 + '>'
$endTag = '</' + [char]0x0413 + [char]0x0440 + [char]0x0443 + [char]0x043F + [char]0x043F + [char]0x0430 + '>'
$start = $text.IndexOf($startTag)
$end = $text.IndexOf($endTag, $start)
$block = $text.Substring($start, $end - $start)
$objPrefix = [char]0x0420 + [char]0x0435 + [char]0x0433 + [char]0x0438 + [char]0x0441 + [char]0x0442 + [char]0x0440 + [char]0x0421 + [char]0x0432 + [char]0x0435 + [char]0x0434 + [char]0x0435 + [char]0x043D + [char]0x0438 + [char]0x0439 + [char]0x0417 + [char]0x0430 + [char]0x043F + [char]0x0438 + [char]0x0441 + [char]0x044C + '.'
$pattern = '<' + [char]0x041E + [char]0x0431 + [char]0x044A + [char]0x0435 + [char]0x043A + [char]0x0442 + [char]0x0412 + [char]0x044B + [char]0x0431 + [char]0x043E + [char]0x0440 + [char]0x043A + [char]0x0438 + '>' + $objPrefix + '([^<]+)</' + [char]0x041E + [char]0x0431 + [char]0x044A + [char]0x0435 + [char]0x043A + [char]0x0442 + [char]0x0412 + [char]0x044B + [char]0x0431 + [char]0x043E + [char]0x0440 + [char]0x043A + [char]0x0438 + '>'
$pvd = [regex]::Matches($block, $pattern) | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
$inBoth = $names | Where-Object { $pvd -contains $_ } | Sort-Object
$inCsvNotPvd = $names | Where-Object { $pvd -notcontains $_ } | Sort-Object
$inPvdNotCsv = $pvd | Where-Object { $names -notcontains $_ } | Sort-Object
Write-Output "CSV count: $($names.Count)"
Write-Output "PVD count: $($pvd.Count)"
Write-Output "both: $($inBoth.Count)"
Write-Output "csv_not_pvd: $($inCsvNotPvd.Count)"
Write-Output "pvd_not_csv: $($inPvdNotCsv.Count)"
Write-Output '--- BOTH ---'
$inBoth
Write-Output '--- CSV NOT PVD ---'
$inCsvNotPvd
Write-Output '--- PVD NOT CSV ---'
$inPvdNotCsv
