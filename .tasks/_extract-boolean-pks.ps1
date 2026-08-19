$OutputEncoding = [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$path = "e:\1C\AY\BPLM-UHLM-XML\BPLM-UH33LM_remix.xml"
$lines = [System.IO.File]::ReadAllLines($path, [Text.UTF8Encoding]::new($false))

function Get-BoolPKS($name, $start, $end) {
    $blockStart = $null
    $blockEnd = $null
    for ($i = $start - 1; $i -lt $end; $i++) {
        if ($lines[$i] -match "<Код>$name</Кod>") {
            for ($j = $i; $j -ge [Math]::Max(0, $start - 30); $j--) {
                if ($lines[$j] -match '^\s*<Правило') { $blockStart = $j; break }
            }
            if ($null -eq $blockStart) { $blockStart = $start - 1 }
            for ($j = $i; $j -lt $end; $j++) {
                if ($lines[$j] -match '</Правило>') { $blockEnd = $j + 1; break }
            }
            break
        }
    }
    $out = @()
    for ($i = $blockStart; $i -lt $blockEnd; $i++) {
        if ($lines[$i] -notmatch 'Тип="Булево"') { continue }
        $prev = if ($i -gt 0) { $lines[$i - 1] } else { '' }
        $combined = $prev + $lines[$i]
        $src = ''
        $dst = ''
        $vid = ''
        if ($combined -match 'Источник Имя="([^"]*)"') { $src = $Matches[1] }
        if ($lines[$i] -match 'Приемник Имя="([^"]*)"') { $dst = $Matches[1] }
        if ($lines[$i] -match 'Вид="([^"]*)"') { $vid = $Matches[1] }
        $group = ''
        for ($j = $i; $j -ge [Math]::Max($blockStart, $i - 40); $j--) {
            if ($lines[$j] -match '<Наименование>(.*?)</Наименование>') { $group = $Matches[1]; break }
        }
        $out += [PSCustomObject]@{ Line = $i + 1; Source = $src; Dest = $dst; Kind = $vid; Group = $group }
    }
    return ,@($blockStart + 1, $blockEnd, $out)
}

$report = @()
foreach ($item in @(
    @{ Name = 'СписаниеСРасчетногоСчета'; Start = 308679; End = 314584 },
    @{ Name = 'ПоступлениеНаРасчетныйСчет'; Start = 440994; End = 450000 }
)) {
    $r = Get-BoolPKS $item.Name $item.Start $item.End
    $report += "=== $($item.Name) (lines $($r[0])-$($r[1])) ==="
    $report += "Count unique dest: $(($r[2] | Select-Object -ExpandProperty Dest -Unique).Count) / total lines: $($r[2].Count)"
    $r[2] | ForEach-Object {
        $src = if ($_.Source) { $_.Source } else { '(empty)' }
        $report += "L$($_.Line): $src -> $($_.Dest) [$($_.Kind)] | $($_.Group)"
    }
    $report += ''
}

$outPath = "e:\1C\AY\BPLM-UHLM-XML\.tasks\_boolean-pks-report.txt"
[System.IO.File]::WriteAllLines($outPath, $report, [Text.UTF8Encoding]::new($true))
Write-Output "Written: $outPath"
