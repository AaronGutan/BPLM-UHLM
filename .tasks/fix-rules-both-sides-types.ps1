# Sanitize KD2 exchange rules for shared BP/UH packaging:
# any Tipo= that is not present on BOTH MD sides is unsafe when Correspondent ~= Exchange.
# ASCII-only source (Cyrillic via \u) for Windows PowerShell 5.1.
param(
	[string]$RulesZip = "",
	[string]$BpMd = "E:\1C\AY\BPLM-UHLM-XML\BP_md_3_0_201_16.xml",
	[string]$UhMd = "E:\1C\AY\BPLM-UHLM-XML\UH33_md.xml",
	[string]$OutDir = "E:\1C\AY\BPLM-UHLM-XML\.tasks"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.FileSystem
. "$PSScriptRoot\RulesXml-SafeWrite.ps1"

if ([string]::IsNullOrWhiteSpace($RulesZip)) {
	$candidate = Get-ChildItem -LiteralPath "E:\1C\AY\BPLM-UHLM-XML" -Filter "*.zip" |
		Where-Object { $_.Name -like "*3.0.201.16*3.3.3.48.zip" -and $_.Name -notlike "*.bak*" -and $_.Name -notlike "*remix*" } |
		Sort-Object LastWriteTime -Descending |
		Select-Object -First 1
	if (-not $candidate) { throw "Rules zip not found by pattern *3.0.201.16*3.3.3.48.zip" }
	$RulesZip = $candidate.FullName
}
Write-Host "RulesZip=$RulesZip"

function U([string]$s) {
	return [regex]::Replace($s, '\\u([0-9A-Fa-f]{4})', {
		param($m)
		return [string][char][Convert]::ToInt32($m.Groups[1].Value, 16)
	})
}

function Get-MdTypeSet([string]$path) {
	Write-Host "MD: $path"
	$set = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
	$settings = New-Object System.Xml.XmlReaderSettings
	$settings.IgnoreComments = $true
	$settings.IgnoreWhitespace = $true
	$settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
	$reader = [System.Xml.XmlReader]::Create($path, $settings)
	$objSuffix = U('\u041e\u0431\u044a\u0435\u043a\u0442\u044b')
	$nameLocal = U('\u0418\u043c\u044f')
	$typeLocal = U('\u0422\u0438\u043f')
	$descLocal = "Description"
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
	$primList = @(
		(U('\u0427\u0438\u0441\u043b\u043e')),
		(U('\u0421\u0442\u0440\u043e\u043a\u0430')),
		(U('\u0411\u0443\u043b\u0435\u0432\u043e')),
		(U('\u0414\u0430\u0442\u0430')),
		(U('\u0425\u0440\u0430\u043d\u0438\u043b\u0438\u0449\u0435\u0417\u043d\u0430\u0447\u0435\u043d\u0438\u044f')),
		(U('\u0423\u043d\u0438\u043a\u0430\u043b\u044c\u043d\u044b\u0439\u0418\u0434\u0435\u043d\u0442\u0438\u0444\u0438\u043a\u0430\u0442\u043e\u0440'))
	)
	foreach ($p in $primList) { [void]$set.Add($p) }

	$depthObj = -1
	$curName = $null
	$curKind = $null
	try {
		while ($reader.Read()) {
			if ($reader.NodeType -eq [System.Xml.XmlNodeType]::Element) {
				$isObj = ($reader.LocalName -eq $objSuffix) -or ($reader.LocalName.EndsWith("." + $objSuffix))
				if ($isObj -and -not $reader.IsEmptyElement) {
					$depthObj = $reader.Depth
					$curName = $null
					$curKind = $null
				}
				elseif ($depthObj -ge 0 -and $reader.Depth -eq ($depthObj + 1)) {
					if ($reader.LocalName -eq $nameLocal -and -not $reader.IsEmptyElement) {
						$curName = $reader.ReadElementContentAsString().Trim()
						continue
					}
					if ($reader.LocalName -eq $typeLocal -and -not $reader.IsEmptyElement) {
						$curKind = $reader.ReadElementContentAsString().Trim()
						continue
					}
					if ($reader.LocalName -eq $descLocal -and -not $reader.IsEmptyElement) {
						$d = $reader.ReadElementContentAsString().Trim()
						if ($d.Length -gt 0) { [void]$set.Add($d) }
						continue
					}
				}
			}
			elseif ($reader.NodeType -eq [System.Xml.XmlNodeType]::EndElement) {
				$isObjEnd = ($reader.LocalName -eq $objSuffix) -or ($reader.LocalName.EndsWith("." + $objSuffix))
				if ($isObjEnd -and $reader.Depth -eq $depthObj) {
					if ($curName -and $curKind) {
						[void]$set.Add($curName)
						[void]$set.Add($curKind)
						if ($kindToPrefix.ContainsKey($curKind)) {
							[void]$set.Add($kindToPrefix[$curKind] + "." + $curName)
						}
					}
					$depthObj = -1
				}
			}
		}
	}
	finally { $reader.Close() }
	Write-Host ("  types={0}" -f $set.Count)
	return $set
}

$elSource = U('\u0418\u0441\u0442\u043e\u0447\u043d\u0438\u043a')
$elDest = U('\u041f\u0440\u0438\u0435\u043c\u043d\u0438\u043a')
$elProp = U('\u0421\u0432\u043e\u0439\u0441\u0442\u0432\u043e')
$elCode = U('\u041a\u043e\u0434')
$elName = U('\u041d\u0430\u0438\u043c\u0435\u043d\u043e\u0432\u0430\u043d\u0438\u0435')
$elOrder = U('\u041f\u043e\u0440\u044f\u0434\u043e\u043a')
$elDisable = U('\u041e\u0442\u043a\u043b\u044e\u0447\u0438\u0442\u044c')
$attrType = U('\u0422\u0438\u043f')
$attrName = U('\u0418\u043c\u044f')
$typeString = U('\u0421\u0442\u0440\u043e\u043a\u0430')
$tipOrg = U('\u0422\u0438\u043f\u041e\u0440\u0433\u0430\u043d\u0438\u0437\u0430\u0446\u0438\u0438')

$prims = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
foreach ($p in @(
		(U('\u0427\u0438\u0441\u043b\u043e')),
		(U('\u0421\u0442\u0440\u043e\u043a\u0430')),
		(U('\u0411\u0443\u043b\u0435\u0432\u043e')),
		(U('\u0414\u0430\u0442\u0430')),
		(U('\u0425\u0440\u0430\u043d\u0438\u043b\u0438\u0449\u0435\u0417\u043d\u0430\u0447\u0435\u043d\u0438\u044f')),
		(U('\u0423\u043d\u0438\u043a\u0430\u043b\u044c\u043d\u044b\u0439\u0418\u0434\u0435\u043d\u0442\u0438\u0444\u0438\u043a\u0430\u0442\u043e\u0440'))
	)) { [void]$prims.Add($p) }

if (-not (Test-Path -LiteralPath $RulesZip)) { throw "ZIP not found: $RulesZip" }

$work = Join-Path $OutDir "_rules-full-fix"
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
New-Item -ItemType Directory -Path $work | Out-Null
Write-Host "Extract ZIP..."
[IO.Compression.ZipFile]::ExtractToDirectory($RulesZip, $work)

$bp = Get-MdTypeSet $BpMd
$uh = Get-MdTypeSet $UhMd

$rxTypeAttr = [regex]($attrType + '="([^"]+)"')
$utf8 = New-Object System.Text.UTF8Encoding $false
$report = New-Object System.Text.StringBuilder
[void]$report.AppendLine("=== Full both-sides rules fix ===")
[void]$report.AppendLine((Get-Date).ToString("s"))
[void]$report.AppendLine("ZIP: $RulesZip")

$totalTypeRepl = 0
$totalPropsRemoved = 0
$totalEmptySrcDisabled = 0

foreach ($fileName in @("ExchangeRules.xml", "CorrespondentExchangeRules.xml")) {
	$path = Join-Path $work $fileName
	if (-not (Test-Path $path)) { throw "Missing $fileName" }
	Write-Host "Process $fileName ..."
	$t = [IO.File]::ReadAllText($path, $utf8)

	$uhOnly = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
	$bpOnly = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
	$unknown = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)

	foreach ($m in $rxTypeAttr.Matches($t)) {
		$typeName = $m.Groups[1].Value.Trim()
		if ([string]::IsNullOrWhiteSpace($typeName)) { continue }
		foreach ($part in ($typeName -split ',\s*')) {
			$pt = $part.Trim()
			if ($prims.Contains($pt)) { continue }
			if (-not $pt.Contains(".")) { continue }
			$inBp = $bp.Contains($pt)
			$inUh = $uh.Contains($pt)
			if ($inBp -and $inUh) { continue }
			if ($inUh -and -not $inBp) { [void]$uhOnly.Add($pt) }
			elseif ($inBp -and -not $inUh) { [void]$bpOnly.Add($pt) }
			else { [void]$unknown.Add($pt) }
		}
	}

	[void]$report.AppendLine("")
	[void]$report.AppendLine("## $fileName")
	[void]$report.AppendLine(("UH-only: {0}" -f $uhOnly.Count))
	foreach ($x in ($uhOnly | Sort-Object)) { [void]$report.AppendLine("  UH_ONLY`t$x") }
	[void]$report.AppendLine(("BP-only: {0}" -f $bpOnly.Count))
	foreach ($x in ($bpOnly | Sort-Object)) { [void]$report.AppendLine("  BP_ONLY`t$x") }
	[void]$report.AppendLine(("Unknown: {0}" -f $unknown.Count))
	foreach ($x in ($unknown | Sort-Object)) { [void]$report.AppendLine("  UNKNOWN`t$x") }

	$badTypes = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
	foreach ($x in $uhOnly) { [void]$badTypes.Add($x) }
	foreach ($x in $bpOnly) { [void]$badTypes.Add($x) }
	foreach ($x in $unknown) { [void]$badTypes.Add($x) }

	# Remove TipOrganizacii PKS entirely (empty source + dest name)
	$rxRemoveTipOrg = [regex](
		'(?s)\s*<' + [regex]::Escape($elProp) + '>\s*<' + [regex]::Escape($elCode) + '>\d+</' + [regex]::Escape($elCode) +
		'>\s*<' + [regex]::Escape($elName) + '>(?:--&gt; --> |--> )?' + [regex]::Escape($tipOrg) +
		'</' + [regex]::Escape($elName) + '>.*?</' + [regex]::Escape($elProp) + '>'
	)
	# Broader: any property whose dest Name=TipOrganizacii
	$rxRemoveTipOrg2 = [regex](
		'(?s)\s*<' + [regex]::Escape($elProp) + '>(?:(?!<' + [regex]::Escape($elProp) + '>).)*?' +
		'<' + [regex]::Escape($elDest) + '\s[^>]*' + [regex]::Escape($attrName) + '="' + [regex]::Escape($tipOrg) +
		'"[^/]*/>.*?</' + [regex]::Escape($elProp) + '>'
	)
	$n1 = $rxRemoveTipOrg2.Matches($t).Count
	$t2 = $rxRemoveTipOrg2.Replace($t, "")
	$totalPropsRemoved += $n1
	if ($n1 -gt 0) { [void]$report.AppendLine("  REMOVED_PKS TipOrganizacii x$n1") }

	foreach ($bt in ($badTypes | Sort-Object)) {
		$literal = $attrType + '="' + $bt + '"'
		$cnt = ([regex]::Matches($t2, [regex]::Escape($literal))).Count
		if ($cnt -gt 0) {
			$t2 = $t2.Replace($literal, $attrType + '="' + $typeString + '"')
			$totalTypeRepl += $cnt
			[void]$report.AppendLine("  REPLACED_TIPO $bt x$cnt")
		}
		# composite lists containing the bad type
		$rxComp = [regex]($attrType + '="([^"]*' + [regex]::Escape($bt) + '[^"]*)"')
		$compMatches = @($rxComp.Matches($t2))
		foreach ($cm in $compMatches) {
			$old = $cm.Groups[1].Value
			$parts = New-Object System.Collections.Generic.List[string]
			foreach ($p in ($old -split ',\s*')) {
				$pt = $p.Trim()
				if ($pt.Length -eq 0) { continue }
				if ($pt -eq $bt) { continue }
				$parts.Add($pt) | Out-Null
			}
			if ($parts.Count -eq 0) { $parts.Add($typeString) | Out-Null }
			$new = [string]::Join(", ", $parts)
			if ($new -ne $old) {
				$t2 = $t2.Replace($attrType + '="' + $old + '"', $attrType + '="' + $new + '"')
				$totalTypeRepl++
				[void]$report.AppendLine("  REPLACED_COMPOSITE $old => $new")
			}
		}
	}

	# Disable empty-source properties (UH fills via algorithm) to avoid exporting UH-only fields to BP
	$rxEmptySrcPattern = '(?s)(<' + [regex]::Escape($elProp) + '>\s*<' + [regex]::Escape($elCode) + '>\d+</' + [regex]::Escape($elCode) +
		'>\s*<' + [regex]::Escape($elName) + '>[^<]*</' + [regex]::Escape($elName) +
		'>\s*<' + [regex]::Escape($elOrder) + '>\d+</' + [regex]::Escape($elOrder) +
		'>\s*<' + [regex]::Escape($elSource) + '\s' + [regex]::Escape($attrName) + '=""\s[^/]*/>\s*<' +
		[regex]::Escape($elDest) + '\s[^/]*/>\s*)(?!<' + [regex]::Escape($elDisable) + '>)'
	$rxEmptySrc = [regex]$rxEmptySrcPattern
	$emptyMatches = $rxEmptySrc.Matches($t2)
	$totalEmptySrcDisabled += $emptyMatches.Count
	$disableInsert = '<' + $elDisable + '>true</' + $elDisable + '>' + "`r`n`t`t`t`t`t`t"
	$t2 = $rxEmptySrc.Replace($t2, '${1}' + $disableInsert)

	if ($t2 -ne $t) {
		Save-RulesXmlAtomic -Path $path -Content $t2 -MinRatioOfOriginal 50
		[void]$report.AppendLine(("  FILE_UPDATED size={0}" -f (Get-Item -LiteralPath $path).Length))
	}
	else {
		[void]$report.AppendLine("  FILE_UNCHANGED")
	}
}

[void]$report.AppendLine("")
[void]$report.AppendLine(("TOTAL tipoReplaced={0} tipOrgRemoved={1} emptySrcDisabled={2}" -f $totalTypeRepl, $totalPropsRemoved, $totalEmptySrcDisabled))

$repPath = Join-Path $OutDir "_rules-full-fix-report.txt"
[IO.File]::WriteAllText($repPath, $report.ToString(), $utf8)

$bak = $RulesZip + ".bak-before-full-fix"
if (-not (Test-Path -LiteralPath $bak)) {
	Copy-Item -LiteralPath $RulesZip -Destination $bak
}
Remove-Item -LiteralPath $RulesZip -Force
[IO.Compression.ZipFile]::CreateFromDirectory($work, $RulesZip, [IO.Compression.CompressionLevel]::Optimal, $false)

Write-Host "REPORT: $repPath"
Write-Host ("ZIP: {0} size={1}" -f $RulesZip, (Get-Item -LiteralPath $RulesZip).Length)
Write-Host "Done."
exit 0
