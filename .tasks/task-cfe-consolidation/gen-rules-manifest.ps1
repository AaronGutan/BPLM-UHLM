# Генерация манифеста: ВСЕ Документ/Справочник из ПВД (включая Отключить=true)
# Для состава плана обмена консолидации нужны и справочники (напр. Валюты),
# даже если в light-правилах группа Справочники отключена.
$ErrorActionPreference = "Stop"

$rulesFile = "e:\1C\AY\BPLM-UHLM-XML\BPLM-UHLM_light.xml"
$configPath = "e:\1C\AY\BPLM-UHLM-XML\acclmcopy"
$outFile = "e:\1C\AY\BPLM-UHLM-XML\.tasks\task-cfe-consolidation\rules-exchange-manifest.json"

if (-not (Test-Path $rulesFile)) { throw "Rules file not found: $rulesFile" }
if (-not (Test-Path $configPath)) { throw "Config path not found: $configPath" }

$prefixDoc = [string]::Concat([char]0x0414, [char]0x043E, [char]0x043A, [char]0x0443, [char]0x043C, [char]0x0435, [char]0x043D, [char]0x0442, [char]0x0421, [char]0x0441, [char]0x044B, [char]0x043B, [char]0x043A, [char]0x0430, ".")
$prefixCat = [string]::Concat([char]0x0421, [char]0x043F, [char]0x0440, [char]0x0430, [char]0x0432, [char]0x043E, [char]0x0447, [char]0x043D, [char]0x0438, [char]0x043A, [char]0x0421, [char]0x0441, [char]0x044B, [char]0x043B, [char]0x043A, [char]0x0430, ".")
$elExportRules = [string]::Concat([char]0x041F, [char]0x0440, [char]0x0430, [char]0x0432, [char]0x0438, [char]0x043B, [char]0x0430, [char]0x0412, [char]0x044B, [char]0x0433, [char]0x0440, [char]0x0443, [char]0x0437, [char]0x043A, [char]0x0438, [char]0x0414, [char]0x0430, [char]0x043D, [char]0x043D, [char]0x044B, [char]0x0445)
$elSelection = [string]::Concat([char]0x041E, [char]0x0431, [char]0x044A, [char]0x0435, [char]0x043A, [char]0x0442, [char]0x0412, [char]0x044B, [char]0x0431, [char]0x043E, [char]0x0440, [char]0x043A, [char]0x0438)
$prefixDelete = [string]::Concat([char]0x0423, [char]0x0434, [char]0x0430, [char]0x043B, [char]0x0438, [char]0x0442, [char]0x044C)

function Parse-SelectionObject([string]$value) {
	$value = $value.Trim()
	if ([string]::IsNullOrWhiteSpace($value)) { return $null }

	$typeRu = $null
	$name = $null
	$mdType = $null
	$odataPrefix = $null

	if ($value.StartsWith($prefixDoc)) {
		$typeRu = "Document"
		$mdType = "Document"
		$odataPrefix = "Document_"
		$name = $value.Substring($prefixDoc.Length)
	}
	elseif ($value.StartsWith($prefixCat)) {
		$typeRu = "Catalog"
		$mdType = "Catalog"
		$odataPrefix = "Catalog_"
		$name = $value.Substring($prefixCat.Length)
	}
	else {
		return $null
	}

	if ([string]::IsNullOrWhiteSpace($name) -or $name.StartsWith($prefixDelete)) {
		return $null
	}

	return [pscustomobject]@{
		type       = $typeRu
		name       = $name
		metadata   = "$mdType.$name"
		odataName  = "$odataPrefix$name"
		mdType     = $mdType
	}
}

$objects = [ordered]@{}
$settings = [System.Xml.XmlReaderSettings]::new()
$settings.IgnoreWhitespace = $true
$settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit

$reader = [System.Xml.XmlReader]::Create($rulesFile, $settings)
try {
	$inExportRules = $false
	$awaitSelection = $false

	while ($reader.Read()) {
		if ($reader.NodeType -eq [System.Xml.XmlNodeType]::Element) {
			$name = $reader.LocalName
			if ($name -eq $elExportRules) {
				$inExportRules = $true
				continue
			}
			if ($inExportRules -and $name -eq $elSelection) {
				$awaitSelection = $true
			}
		}
		elseif ($reader.NodeType -eq [System.Xml.XmlNodeType]::Text -and $awaitSelection) {
			$parsed = Parse-SelectionObject $reader.Value
			if ($null -ne $parsed -and -not $objects.Contains($parsed.odataName)) {
				$objects[$parsed.odataName] = $parsed
			}
			$awaitSelection = $false
		}
		elseif ($reader.NodeType -eq [System.Xml.XmlNodeType]::EndElement) {
			$name = $reader.LocalName
			if ($name -eq $elExportRules) { break }
			elseif ($name -eq $elSelection) { $awaitSelection = $false }
		}
	}
}
finally {
	$reader.Close()
}

$catalogs = New-Object System.Collections.Generic.List[object]
$documents = New-Object System.Collections.Generic.List[object]
$missing = New-Object System.Collections.Generic.List[string]

foreach ($key in $objects.Keys) {
	$item = $objects[$key]
	$relPath = if ($item.mdType -eq "Catalog") {
		Join-Path "Catalogs" ($item.name + ".xml")
	} else {
		Join-Path "Documents" ($item.name + ".xml")
	}
	$fullPath = Join-Path $configPath $relPath
	$exists = Test-Path $fullPath

	$enriched = [pscustomobject]@{
		type           = $item.type
		name           = $item.name
		metadata       = $item.metadata
		odataName      = $item.odataName
		existsInConfig = $exists
	}

	if ($exists) {
		if ($item.mdType -eq "Catalog") { $catalogs.Add($enriched) | Out-Null }
		else { $documents.Add($enriched) | Out-Null }
	}
	else {
		$missing.Add($item.metadata) | Out-Null
	}
}

$catalogsSorted = @($catalogs | Sort-Object name)
$documentsSorted = @($documents | Sort-Object name)

$manifest = [ordered]@{
	sourceRules    = $rulesFile
	configPath     = $configPath
	generatedAt    = (Get-Date).ToString("s")
	includeDisabledPvd = $true
	note           = "All Document/Catalog from PVD including Отключить=true groups (needed for exchange plan composition)"
	totalInRules   = $objects.Count
	catalogsCount  = $catalogsSorted.Count
	documentsCount = $documentsSorted.Count
	missingCount   = $missing.Count
	missing        = @($missing | Sort-Object)
	catalogs       = $catalogsSorted
	documents      = $documentsSorted
	objects        = @($catalogsSorted + $documentsSorted)
}

$json = $manifest | ConvertTo-Json -Depth 6
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($outFile, $json, $utf8NoBom)

Write-Host "Total in rules: $($objects.Count)"
Write-Host "Catalogs present: $($catalogsSorted.Count)"
Write-Host "Documents present: $($documentsSorted.Count)"
Write-Host "Missing: $($missing.Count)"
if ($missing.Count -gt 0) {
	$missing | ForEach-Object { Write-Host "  MISSING: $_" }
}
$hasVal = $catalogsSorted | Where-Object { $_.name -eq ([string]::Concat([char]0x0412,[char]0x0430,[char]0x043B,[char]0x044E,[char]0x0442,[char]0x044B)) }
Write-Host "Has Catalog.Valyuty: $($null -ne $hasVal)"
Write-Host "File: $outFile"