#Requires -Version 5.1
param(
    [string]$Path = (Join-Path $PSScriptRoot '..\BPLM-UHLM.xml')
)
$ErrorActionPreference = 'Stop'
$xml = New-Object System.Xml.XmlDocument
$xml.PreserveWhitespace = $true
$xml.Load((Resolve-Path $Path).Path)
$ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)

$pkoRules = $xml.SelectNodes('//ПравилаКонвертацииОбъектов//Правило[Источник and Приемник]', $ns)
$exportRules = $xml.SelectNodes('//ПравилаВыгрузкиДанных//Правило[ОбъектВыборки]', $ns)

$byReceiver = @{}
$bySource = @{}
foreach ($rule in $pkoRules) {
    $src = $rule.SelectSingleNode('Источник', $ns).InnerText.Trim()
    $dst = $rule.SelectSingleNode('Приемник', $ns).InnerText.Trim()
    if (-not $byReceiver.ContainsKey($dst)) { $byReceiver[$dst] = 0 }
    if (-not $bySource.ContainsKey($src)) { $bySource[$src] = 0 }
    $byReceiver[$dst]++
    $bySource[$src]++
}

$exportObjects = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($rule in $exportRules) {
    $obj = $rule.SelectSingleNode('ОбъектВыборки', $ns).InnerText.Trim()
    [void]$exportObjects.Add($obj)
}

function Get-TypeKind([string]$TypeName) {
    if ($TypeName -match '^([^\.]+)\.') { return $Matches[1] }
    return 'Unknown'
}

$receiverKinds = @{}
foreach ($k in $byReceiver.Keys) {
    $kind = Get-TypeKind $k
    if (-not $receiverKinds.ContainsKey($kind)) { $receiverKinds[$kind] = 0 }
    $receiverKinds[$kind]++
}

$result = [ordered]@{
    File = $Path
    ExchangeName = $xml.SelectSingleNode('//Наименование', $ns).InnerText.Trim()
    SourceConfig = $xml.SelectSingleNode('//Источник', $ns).GetAttribute('СинонимКонфигурации')
    TargetConfig = $xml.SelectSingleNode('//Приемник', $ns).GetAttribute('СинонимКонфигурации')
    PKORulesCount = $pkoRules.Count
    ExportRulesCount = $exportRules.Count
    UniqueReceiverTypes = $byReceiver.Count
    UniqueSourceTypes = $bySource.Count
    ReceiverKinds = $receiverKinds
    ExportObjectKinds = ($exportObjects | ForEach-Object { Get-TypeKind $_ } | Group-Object | ForEach-Object { @{ Kind = $_.Name; Count = $_.Count } })
    SyncByIdRules = ($pkoRules | Where-Object { $_.SelectSingleNode('СинхронизироватьПоИдентификатору', $ns) -and $_.SelectSingleNode('СинхронизироватьПоИдентификатору', $ns).InnerText -eq 'true' }).Count
    HasCleanupRules = [bool]($xml.SelectSingleNode('//ПравилаОчисткиДанных/Правило', $ns))
}

$outPath = Join-Path $PSScriptRoot '..\bplm-rules-analysis.json'
$result | ConvertTo-Json -Depth 5 | Set-Content -Path $outPath -Encoding UTF8
Write-Host "Saved: $outPath"
$result | ConvertTo-Json -Depth 5
