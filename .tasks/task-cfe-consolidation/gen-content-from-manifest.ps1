$ErrorActionPreference = "Stop"
$manifestFile = "e:\1C\AY\BPLM-UHLM-XML\.tasks\task-cfe-consolidation\rules-exchange-manifest.json"
$outFile = "e:\1C\AY\BPLM-UHLM-XML\acclmcopy-cfe-consolidation\ExchangePlans\Консолидация\Ext\Content.xml"

$data = Get-Content $manifestFile -Raw -Encoding UTF8 | ConvertFrom-Json
$metadataItems = New-Object System.Collections.Generic.List[string]

foreach ($cat in ($data.catalogs | Sort-Object name)) {
	$metadataItems.Add($cat.metadata) | Out-Null
}
foreach ($doc in ($data.documents | Sort-Object name)) {
	$metadataItems.Add($doc.metadata) | Out-Null
}

$dir = Split-Path $outFile -Parent
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

$sb = New-Object System.Text.StringBuilder
$nl = "`r`n"
[void]$sb.Append('<?xml version="1.0" encoding="UTF-8"?>' + $nl)
[void]$sb.Append('<ExchangePlanContent xmlns="http://v8.1c.ru/8.3/xcf/extrnprops" xmlns:xr="http://v8.1c.ru/8.3/xcf/readable" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="2.20">' + $nl)

foreach ($md in $metadataItems) {
	[void]$sb.Append("`t<Item>" + $nl)
	[void]$sb.Append("`t`t<Metadata>$md</Metadata>" + $nl)
	[void]$sb.Append("`t`t<AutoRecord>Allow</AutoRecord>" + $nl)
	[void]$sb.Append("`t</Item>" + $nl)
}
[void]$sb.Append('</ExchangePlanContent>' + $nl)

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($outFile, $sb.ToString(), $utf8NoBom)

Write-Host "Items: $($metadataItems.Count)"
Write-Host "Catalogs: $($data.catalogsCount) Documents: $($data.documentsCount)"
Write-Host "File: $outFile"
$hasVal = $metadataItems | Where-Object { $_ -like "Catalog.*" -and $_.EndsWith(([string]::Concat([char]0x0412,[char]0x0430,[char]0x043B,[char]0x044E,[char]0x0442,[char]0x044B))) }
Write-Host "Has Valyuty: $($null -ne $hasVal)"