# Генерация списка объектов для плана обмена Консолидация
# Источник: конфигурация acclmcopy (БП КОРП)

$ErrorActionPreference = "Stop"
$cfg = "e:\1C\AY\acclmcopy"
$docsDir = Join-Path $cfg "Documents"
$cocFile = Join-Path $cfg "ChartsOfCharacteristicTypes\ВидыСубконтоХозрасчетные.xml"

$utf8 = New-Object System.Text.UTF8Encoding($false)

# 1. Документы с движениями по регистру Хозрасчетный (без префикса Удалить)
$docFiles = [System.IO.Directory]::GetFiles($docsDir, "*.xml")
$documents = New-Object System.Collections.Generic.List[string]
$catalogsFromAttrs = New-Object System.Collections.Generic.HashSet[string]

foreach ($f in $docFiles) {
    $name = [System.IO.Path]::GetFileNameWithoutExtension($f)
    if ($name -like "Удалить*") { continue }
    $text = [System.IO.File]::ReadAllText($f, [System.Text.Encoding]::UTF8)
    if ($text -notmatch "AccountingRegister\.Хозрасчетный") { continue }
    $documents.Add($name) | Out-Null

    # Справочники-реквизиты документа
    $matches = [regex]::Matches($text, "cfg:CatalogRef\.([А-Яа-яЁёA-Za-z0-9_]+)")
    foreach ($m in $matches) {
        $catalogsFromAttrs.Add($m.Groups[1].Value) | Out-Null
    }
}

# 2. Справочники-субконто из ВидыСубконтоХозрасчетные
$cocText = [System.IO.File]::ReadAllText($cocFile, [System.Text.Encoding]::UTF8)
$catalogsFromSubconto = New-Object System.Collections.Generic.HashSet[string]
$matchesSub = [regex]::Matches($cocText, "cfg:CatalogRef\.([А-Яа-яЁёA-Za-z0-9_]+)")
foreach ($m in $matchesSub) {
    $catalogsFromSubconto.Add($m.Groups[1].Value) | Out-Null
}

# 3. Объединение всех справочников
$allCatalogs = New-Object System.Collections.Generic.HashSet[string]
foreach ($c in $catalogsFromSubconto) { $allCatalogs.Add($c) | Out-Null }
foreach ($c in $catalogsFromAttrs) { $allCatalogs.Add($c) | Out-Null }

# Убрать справочники с префиксом Удалить
$catalogsClean = @($allCatalogs | Where-Object { $_ -notlike "Удалить*" } | Sort-Object)
$docsClean = @($documents | Sort-Object)

# Вывод результата в JSON
$result = [ordered]@{
    documents = $docsClean
    catalogs = $catalogsClean
    catalogsFromSubconto = @($catalogsFromSubconto | Sort-Object)
    catalogsFromAttrs = @($catalogsFromAttrs | Sort-Object)
    countDocuments = $docsClean.Count
    countCatalogs = $catalogsClean.Count
}

$json = $result | ConvertTo-Json -Depth 5
$outFile = "e:\1C\AY\BPLM-UHLM-XML\.tasks\task-cfe-consolidation\object-list.json"
[System.IO.File]::WriteAllText($outFile, $json, $utf8)

Write-Host "Документов: $($docsClean.Count)"
Write-Host "Справочников всего: $($catalogsClean.Count)"
Write-Host "  из субконто: $($catalogsFromSubconto.Count)"
Write-Host "  из реквизитов: $($catalogsFromAttrs.Count)"
Write-Host "Результат: $outFile"
