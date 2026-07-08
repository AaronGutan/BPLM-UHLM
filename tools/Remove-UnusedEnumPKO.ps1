param(
    [string]$Path = (Join-Path $PSScriptRoot '..\BPLM-UHLM.xml'),
    [string]$ReportPath = (Join-Path $PSScriptRoot '..\remove-unused-enum-pko-report.txt')
)
$ErrorActionPreference = 'Stop'
Write-Host "Loading: $Path"
$xml = New-Object System.Xml.XmlDocument
$xml.PreserveWhitespace = $true
$xml.Load((Resolve-Path $Path).Path)
$ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
$pkoRoot = $xml.SelectSingleNode('//ПравилаКонвертацииОбъектов', $ns)
$enumRules = $pkoRoot.SelectNodes(".//Правило[starts-with(normalize-space(Источник),'ПеречислениеСсылка.')]", $ns)
Write-Host "Enum PKO rules: $($enumRules.Count)"
$usedEnumTypes = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($n in $xml.SelectNodes('//*[@Тип[starts-with(., "ПеречислениеСсылка.")]]', $ns)) {
    $t = $n.GetAttribute('Тип')
    if ($t -match '^ПеречислениеСсылка\.(.+)$') { [void]$usedEnumTypes.Add($Matches[1]) }
}
$allRefNodes = $xml.SelectNodes('//КодПравилаКонвертации', $ns)
$exportRoot = $xml.SelectSingleNode('//ПравилаВыгрузкиДанных', $ns)
$exportCodes = New-Object 'System.Collections.Generic.HashSet[string]'
if ($exportRoot) {
    foreach ($n in $exportRoot.SelectNodes('.//КодПравилаКонвертации', $ns)) {
        $c = $n.InnerText.Trim()
        if ($c) { [void]$exportCodes.Add($c) }
    }
}
$toRemove = New-Object System.Collections.Generic.List[object]
$keepCount = 0
foreach ($rule in $enumRules) {
    $codeNode = $rule.SelectSingleNode('Код', $ns)
    $srcNode = $rule.SelectSingleNode('Источник', $ns)
    if (-not $codeNode -or -not $srcNode) { continue }
    $code = $codeNode.InnerText.Trim()
    if ($srcNode.InnerText -notmatch '^ПеречислениеСсылка\.(.+)$') { continue }
    $enumName = $Matches[1].Trim()
    $used = $false
    if ($usedEnumTypes.Contains($enumName)) { $used = $true }
    if ($exportCodes.Contains($code)) { $used = $true }
    if (-not $used) {
        foreach ($ref in $allRefNodes) {
            if ($ref.InnerText.Trim() -ne $code) { continue }
            $ancestorRule = $ref
            while ($ancestorRule -and $ancestorRule.LocalName -ne 'Правило') { $ancestorRule = $ancestorRule.ParentNode }
            if ($ancestorRule -and $ancestorRule -ne $rule) { $used = $true; break }
        }
    }
    if ($used) { $keepCount++ } else { $toRemove.Add([pscustomobject]@{ Code = $code; EnumName = $enumName; Rule = $rule }) | Out-Null }
}
$report = @("Remove unused enum PKO - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')", "Total: $($enumRules.Count)", "Keep: $keepCount", "Remove: $($toRemove.Count)", '', '=== REMOVE ===')
$toRemove | Sort-Object Code | ForEach-Object { $report += "$($_.Code) -> $($_.EnumName)" }
foreach ($item in $toRemove) { [void]$item.Rule.ParentNode.RemoveChild($item.Rule) }
$xml.Save((Resolve-Path $Path).Path)
$report | Set-Content -Path $ReportPath -Encoding UTF8
Write-Host "Removed: $($toRemove.Count)"