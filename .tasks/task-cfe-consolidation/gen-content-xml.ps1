# Генерация Content.xml плана обмена Консолидация
$ErrorActionPreference = "Stop"

$jsonFile = "e:\1C\AY\BPLM-UHLM-XML\.tasks\task-cfe-consolidation\object-list.json"
$outFile = "e:\1C\AY\BPLM-UHLM-XML\acclmcopy-cfe-consolidation\ExchangePlans\Консолидация\Ext\Content.xml"

$data = Get-Content $jsonFile -Raw -Encoding UTF8 | ConvertFrom-Json

# Формируем упорядоченный список метаданных
$metadataItems = New-Object System.Collections.Generic.List[string]

# Источники консолидации: план счетов и план видов характеристик субконто
$metadataItems.Add("ChartOfAccounts.Хозрасчетный") | Out-Null
$metadataItems.Add("ChartOfCharacteristicTypes.ВидыСубконтоХозрасчетные") | Out-Null

# Документы с движениями по регистру Хозрасчетный
foreach ($doc in $data.documents) {
    if ($doc -like "Удалить*") { continue }
    $metadataItems.Add("Document.$doc") | Out-Null
}

# Справочники-субконто и справочники-реквизиты документов
foreach ($cat in $data.catalogs) {
    if ($cat -like "Удалить*") { continue }
    $metadataItems.Add("Catalog.$cat") | Out-Null
}

# Сборка XML
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

Write-Host "Объектов в составе: $($metadataItems.Count)"
Write-Host "  документов: $($data.documents.Count)"
Write-Host "  справочников: $($data.catalogs.Count)"
Write-Host "  + ChartOfAccounts.Хозрасчетный, ChartOfCharacteristicTypes.ВидыСубконтоХозрасчетные"
Write-Host "Файл: $outFile"
