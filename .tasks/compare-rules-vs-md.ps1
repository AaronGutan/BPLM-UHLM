param(
	[string]$RulesZip = "E:\1C\AY\BPLM-UHLM-XML\BPLM-UH33LM_remix.zip",
	[string]$BpMd = "E:\1C\AY\BPLM-UHLM-XML\BP_md_3_0_201_16.xml",
	[string]$UhMd = "E:\1C\AY\BPLM-UHLM-XML\UH33_md.xml",
	[string]$OutDir = "E:\1C\AY\BPLM-UHLM-XML\.tasks"
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.FileSystem

function U([string]$s) {
	return [regex]::Replace($s, '\\u([0-9A-Fa-f]{4})', { param($m) [string][char][Convert]::ToInt32($m.Groups[1].Value, 16) })
}

function Get-MdTypeSet([string]$path) {
	Write-Host "XmlReader MD: $path"
	$set = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
	$settings = New-Object System.Xml.XmlReaderSettings
	$settings.IgnoreComments = $true
	$settings.IgnoreWhitespace = $true
	$settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
	$reader = [System.Xml.XmlReader]::Create($path, $settings)
	$objSuffix = U('\u041e\u0431\u044a\u0435\u043a\u0442\u044b')
	$nameLocal = U('\u0418\u043c\u044f')
	$typeLocal = U('\u0422\u0438\u043f')
	$descLocal = 'Description'
	$kindToPrefix = @{
		(U('\u0421\u043f\u0440\u0430\u0432\u043e\u0447\u043d\u0438\u043a')) = (U('\u0421\u043f\u0440\u0430\u0432\u043e\u0447\u043d\u0438\u043a\u0421\u0441\u044b\u043b\u043a\u0430'))
		(U('\u0414\u043e\u043a\u0443\u043c\u0435\u043d\u0442')) = (U('\u0414\u043e\u043a\u0443\u043c\u0435\u043d\u0442\u0421\u0441\u044b\u043b\u043a\u0430'))
		(U('\u041f\u0435\u0440\u0435\u0447\u0438\u0441\u043b\u0435\u043d\u0438\u0435')) = (U('\u041f\u0435\u0440\u0435\u0447\u0438\u0441\u043b\u0435\u043d\u0438\u0435\u0421\u0441\u044b\u043b\u043a\u0430'))
		(U('\u041f\u043b\u0430\u043d\u0412\u0438\u0434\u043e\u0432\u0425\u0430\u0440\u0430\u043a\u0442\u0435\u0440\u0438\u0441\u0442\u0438\u043a')) = (U('\u041f\u043b\u0430\u043d\u0412\u0438\u0434\u043e\u0432\u0425\u0430\u0440\u0430\u043a\u0442\u0435\u0440\u0438\u0441\u0442\u0438\u043a\u0421\u0441\u044b\u043b\u043a\u0430'))
		(U('\u041f\u043b\u0430\u043d\u0421\u0447\u0435\u0442\u043e\u0432')) = (U('\u041f\u043b\u0430\u043d\u0421\u0447\u0435\u0442\u043e\u0432\u0421\u0441\u044b\u043b\u043a\u0430'))
		(U('\u041f\u043b\u0430\u043d\u0412\u0438\u0434\u043e\u0432\u0420\u0430\u0441\u0447\u0435\u0442\u0430')) = (U('\u041f\u043b\u0430\u043d\u0412\u0438\u0434\u043e\u0432\u0420\u0430\u0441\u0447\u0435\u0442\u0430\u0421\u0441\u044b\u043b\u043a\u0430'))
		(U('\u0411\u0438\u0437\u043d\u0435\u0441\u041f\u0440\u043e\u0446\u0435\u0441\u0441')) = (U('\u0411\u0438\u0437\u043d\u0435\u0441\u041f\u0440\u043e\u0446\u0435\u0441\u0441\u0421\u0441\u044b\u043b\u043a\u0430'))
		(U('\u0417\u0430\u0434\u0430\u0447\u0430')) = (U('\u0417\u0430\u0434\u0430\u0447\u0430\u0421\u0441\u044b\u043b\u043a\u0430'))
		(U('\u041f\u043b\u0430\u043d\u041e\u0431\u043c\u0435\u043d\u0430')) = (U('\u041f\u043b\u0430\u043d\u041e\u0431\u043c\u0435\u043d\u0430\u0421\u0441\u044b\u043b\u043a\u0430'))
		(U('\u0420\u0435\u0433\u0438\u0441\u0442\u0440\u0421\u0432\u0435\u0434\u0435\u043d\u0438\u0439')) = (U('\u0420\u0435\u0433\u0438\u0441\u0442\u0440\u0421\u0432\u0435\u0434\u0435\u043d\u0438\u0439\u0417\u0430\u043f\u0438\u0441\u044c'))
		(U('\u0420\u0435\u0433\u0438\u0441\u0442\u0440\u041d\u0430\u043a\u043e\u043f\u043b\u0435\u043d\u0438\u044f')) = (U('\u0420\u0435\u0433\u0438\u0441\u0442\u0440\u041d\u0430\u043a\u043e\u043f\u043b\u0435\u043d\u0438\u044f\u0417\u0430\u043f\u0438\u0441\u044c'))
		(U('\u0420\u0435\u0433\u0438\u0441\u0442\u0440\u0411\u0443\u0445\u0433\u0430\u043b\u0442\u0435\u0440\u0438\u0438')) = (U('\u0420\u0435\u0433\u0438\u0441\u0442\u0440\u0411\u0443\u0445\u0433\u0430\u043b\u0442\u0435\u0440\u0438\u0438\u0417\u0430\u043f\u0438\u0441\u044c'))
		(U('\u0420\u0435\u0433\u0438\u0441\u0442\u0440\u0420\u0430\u0441\u0447\u0435\u0442\u0430')) = (U('\u0420\u0435\u0433\u0438\u0441\u0442\u0440\u0420\u0430\u0441\u0447\u0435\u0442\u0430\u0417\u0430\u043f\u0438\u0441\u044c'))
	}
	foreach ($p in @(
			(U('\u0427\u0438\u0441\u043b\u043e')),(U('\u0421\u0442\u0440\u043e\u043a\u0430')),(U('\u0411\u0443\u043b\u0435\u0432\u043e')),
			(U('\u0414\u0430\u0442\u0430')),(U('\u0425\u0440\u0430\u043d\u0438\u043b\u0438\u0449\u0435\u0417\u043d\u0430\u0447\u0435\u043d\u0438\u044f')),
			(U('\u0423\u043d\u0438\u043a\u0430\u043b\u044c\u043d\u044b\u0439\u0418\u0434\u0435\u043d\u0442\u0438\u0444\u0438\u043a\u0430\u0442\u043e\u0440'))
		)) { [void]$set.Add($p) }

	$depthObj = -1
	$curName = $null
	$curKind = $null
	$n = 0
	try {
		while ($reader.Read()) {
			if ($reader.NodeType -eq [System.Xml.XmlNodeType]::Element) {
				$isObj = ($reader.LocalName -eq $objSuffix) -or ($reader.LocalName.EndsWith('.' + $objSuffix))
				if ($isObj -and -not $reader.IsEmptyElement) {
					$depthObj = $reader.Depth
					$curName = $null
					$curKind = $null
				}
				elseif ($depthObj -ge 0 -and $reader.Depth -eq ($depthObj + 1)) {
					if ($reader.LocalName -eq $nameLocal -and -not $reader.IsEmptyElement) {
						$curName = $reader.ReadElementContentAsString().Trim(); continue
					}
					if ($reader.LocalName -eq $typeLocal -and -not $reader.IsEmptyElement) {
						$curKind = $reader.ReadElementContentAsString().Trim(); continue
					}
					if ($reader.LocalName -eq $descLocal -and -not $reader.IsEmptyElement) {
						$d = $reader.ReadElementContentAsString().Trim()
						if ($d.Length -gt 0) { [void]$set.Add($d) }
						continue
					}
				}
			}
			elseif ($reader.NodeType -eq [System.Xml.XmlNodeType]::EndElement) {
				$isObjEnd = ($reader.LocalName -eq $objSuffix) -or ($reader.LocalName.EndsWith('.' + $objSuffix))
				if ($isObjEnd -and $reader.Depth -eq $depthObj) {
					if ($curName -and $curKind) {
						[void]$set.Add($curName)
						[void]$set.Add($curKind)
						if ($kindToPrefix.ContainsKey($curKind)) {
							[void]$set.Add($kindToPrefix[$curKind] + '.' + $curName)
						}
					}
					$depthObj = -1
					$n++
					if (($n % 5000) -eq 0) { Write-Host "  objects=$n types=$($set.Count)" }
				}
			}
		}
	} finally { $reader.Close() }
	Write-Host "  DONE objects=$n types=$($set.Count)"
	return $set
}

function Get-RulesTypes([string]$rulesPath) {
	Write-Host "Parsing rules: $rulesPath"
	$src = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
	$dst = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
	$text = [IO.File]::ReadAllText($rulesPath, [Text.UTF8Encoding]::new($false))
	$srcEl = U('\u0418\u0441\u0442\u043e\u0447\u043d\u0438\u043a')
	$dstEl = U('\u041f\u0440\u0438\u0435\u043c\u043d\u0438\u043a')
	$typeAttr = U('\u0422\u0438\u043f')
	$refToken = U('\u0421\u0441\u044b\u043b\u043a\u0430.')
	$prims = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
	foreach ($p in @(
			(U('\u0427\u0438\u0441\u043b\u043e')),(U('\u0421\u0442\u0440\u043e\u043a\u0430')),(U('\u0411\u0443\u043b\u0435\u0432\u043e')),
			(U('\u0414\u0430\u0442\u0430')),(U('\u0425\u0440\u0430\u043d\u0438\u043b\u0438\u0449\u0435\u0417\u043d\u0430\u0447\u0435\u043d\u0438\u044f')),
			(U('\u0423\u043d\u0438\u043a\u0430\u043b\u044c\u043d\u044b\u0439\u0418\u0434\u0435\u043d\u0442\u0438\u0444\u0438\u043a\u0430\u0442\u043e\u0440'))
		)) { [void]$prims.Add($p) }

	$rxSrcAttr = [regex]('<' + [regex]::Escape($srcEl) + '[^>]*\s' + [regex]::Escape($typeAttr) + '="([^"]+)"')
	$rxDstAttr = [regex]('<' + [regex]::Escape($dstEl) + '[^>]*\s' + [regex]::Escape($typeAttr) + '="([^"]+)"')
	foreach ($m in $rxSrcAttr.Matches($text)) { [void]$src.Add($m.Groups[1].Value.Trim()) }
	foreach ($m in $rxDstAttr.Matches($text)) { [void]$dst.Add($m.Groups[1].Value.Trim()) }

	$rxSrcRoot = [regex]('<' + [regex]::Escape($srcEl) + '>([^<]+)</' + [regex]::Escape($srcEl) + '>')
	$rxDstRoot = [regex]('<' + [regex]::Escape($dstEl) + '>([^<]+)</' + [regex]::Escape($dstEl) + '>')
	foreach ($m in $rxSrcRoot.Matches($text)) {
		$t = $m.Groups[1].Value.Trim()
		if ($t.Contains($refToken) -or $prims.Contains($t) -or $t.Contains('.')) { [void]$src.Add($t) }
	}
	foreach ($m in $rxDstRoot.Matches($text)) {
		$t = $m.Groups[1].Value.Trim()
		if ($t.Contains($refToken) -or $prims.Contains($t) -or $t.Contains('.')) { [void]$dst.Add($t) }
	}
	Write-Host "  sourceTypes=$($src.Count) destTypes=$($dst.Count)"
	return @{ Source = $src; Dest = $dst }
}

function Get-Missing($ruleSet, $mdSet) {
	$list = New-Object System.Collections.Generic.List[string]
	foreach ($t in ($ruleSet | Sort-Object)) {
		if ([string]::IsNullOrWhiteSpace($t)) { continue }
		if (-not $mdSet.Contains([string]$t)) { $list.Add([string]$t) | Out-Null }
	}
	return $list
}

if (-not (Test-Path $RulesZip)) { throw "ZIP not found: $RulesZip" }
if (-not (Test-Path $BpMd)) { throw "BP MD not found: $BpMd" }
if (-not (Test-Path $UhMd)) { throw "UH MD not found: $UhMd" }

$work = Join-Path $OutDir "_rules-md-check"
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
New-Item -ItemType Directory -Path $work | Out-Null
Write-Host "Extracting ExchangeRules.xml..."
[IO.Compression.ZipFile]::ExtractToDirectory($RulesZip, $work)
$rulesPath = Join-Path $work "ExchangeRules.xml"
if (-not (Test-Path $rulesPath)) { throw "ExchangeRules.xml missing in ZIP" }

$bpTypes = Get-MdTypeSet $BpMd
$uhTypes = Get-MdTypeSet $UhMd
$rules = Get-RulesTypes $rulesPath
$missingSrc = Get-Missing $rules.Source $bpTypes
$missingDst = Get-Missing $rules.Dest $uhTypes
Write-Host "BP_missing=$($missingSrc.Count) UH_missing=$($missingDst.Count)"

$utf8 = New-Object System.Text.UTF8Encoding $false
$report = Join-Path $OutDir "_rules-vs-md-types.txt"
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("=== Rules vs metadata type check ===")
[void]$sb.AppendLine("ZIP: $RulesZip")
[void]$sb.AppendLine("BP MD: $BpMd (types=$($bpTypes.Count))")
[void]$sb.AppendLine("UH MD: $UhMd (types=$($uhTypes.Count))")
[void]$sb.AppendLine("Rules source types: $($rules.Source.Count); dest types: $($rules.Dest.Count)")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("--- MISSING ON BP (source) : $($missingSrc.Count) ---")
foreach ($t in $missingSrc) { [void]$sb.AppendLine($t) }
[void]$sb.AppendLine("")
[void]$sb.AppendLine("--- MISSING ON UH (receiver) : $($missingDst.Count) ---")
foreach ($t in $missingDst) { [void]$sb.AppendLine($t) }
[IO.File]::WriteAllText($report, $sb.ToString(), $utf8)

$json = [ordered]@{
	CheckedAt = (Get-Date).ToString('s')
	Zip = $RulesZip
	BpTypes = $bpTypes.Count
	UhTypes = $uhTypes.Count
	RulesSourceTypes = $rules.Source.Count
	RulesDestTypes = $rules.Dest.Count
	MissingOnBpCount = $missingSrc.Count
	MissingOnUhCount = $missingDst.Count
	MissingOnBp = @($missingSrc)
	MissingOnUh = @($missingDst)
}
[IO.File]::WriteAllText((Join-Path $OutDir "_rules-vs-md-types.json"), ($json | ConvertTo-Json -Depth 4), $utf8)
Write-Host "REPORT: $report"
if ($missingSrc.Count -gt 0 -or $missingDst.Count -gt 0) { exit 2 }
exit 0