# Remove ALL PKS (Свойство) with empty source name Имя="" from rules XML.
# Disable/Отключить is NOT enough: algorithms still get into exchange messages.
# ASCII-only source for Windows PowerShell 5.1.
param(
	[string]$OutDir = "E:\1C\AY\BPLM-UHLM-XML\.tasks"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.FileSystem
. "$PSScriptRoot\RulesXml-SafeWrite.ps1"

function U([string]$s) {
	return [regex]::Replace($s, '\\u([0-9A-Fa-f]{4})', {
		param($m)
		return [string][char][Convert]::ToInt32($m.Groups[1].Value, 16)
	})
}

$elProp = U('\u0421\u0432\u043e\u0439\u0441\u0442\u0432\u043e')
$elGrp = U('\u0413\u0440\u0443\u043f\u043f\u0430')
$elSource = U('\u0418\u0441\u0442\u043e\u0447\u043d\u0438\u043a')
$attrName = U('\u0418\u043c\u044f')
$utf8 = New-Object System.Text.UTF8Encoding $false

# Match a property block that contains empty-name source. No nested Свойство expected inside PKS.
$rxEmptySrcProp = [regex](
	'(?s)\s*<' + [regex]::Escape($elProp) + '(?:\s[^>]*)?>' +
	'(?:(?!<' + [regex]::Escape($elProp) + '(?:\s|>)).)*?' +
	'<' + [regex]::Escape($elSource) + '\s[^>]*\b' + [regex]::Escape($attrName) + '=""[^>/]*/?>' +
	'(?:(?!<' + [regex]::Escape($elProp) + '(?:\s|>)).)*?' +
	'</' + [regex]::Escape($elProp) + '>'
)
# Leaf groups with empty source (no nested Prop/Group)
$rxEmptySrcGrp = [regex](
	'(?s)\s*<' + [regex]::Escape($elGrp) + '(?:\s[^>]*)?>' +
	'(?:(?!<' + [regex]::Escape($elGrp) + '(?:\s|>))(?!<' + [regex]::Escape($elProp) + '(?:\s|>)).)*?' +
	'<' + [regex]::Escape($elSource) + '\s[^>]*\b' + [regex]::Escape($attrName) + '=""[^>/]*/?>' +
	'(?:(?!<' + [regex]::Escape($elGrp) + '(?:\s|>))(?!<' + [regex]::Escape($elProp) + '(?:\s|>)).)*?' +
	'</' + [regex]::Escape($elGrp) + '>'
)

function Remove-EmptySourceProps([string]$path, [System.Text.StringBuilder]$report) {
	if (-not (Test-Path -LiteralPath $path)) {
		[void]$report.AppendLine("MISSING $path")
		return
	}
	$t = [IO.File]::ReadAllText($path, $utf8)
	$field = U('\u0418\u0441\u043f\u043e\u043b\u044c\u0437\u043e\u0432\u0430\u0442\u044c\u0412\u0420\u0435\u0433\u043b\u0430\u043c\u0435\u043d\u0442\u0438\u0440\u043e\u0432\u0430\u043d\u043d\u043e\u043c\u0423\u0447\u0435\u0442\u0435')
	$beforeField = ([regex]::Matches($t, [regex]::Escape($field))).Count
	$beforeEmpty = ([regex]::Matches($t, [regex]::Escape($elSource) + '\s[^>]*' + [regex]::Escape($attrName) + '=""')).Count
	$nProp = $rxEmptySrcProp.Matches($t).Count
	$t2 = $rxEmptySrcProp.Replace($t, "")
	$nGrp = $rxEmptySrcGrp.Matches($t2).Count
	$t2 = $rxEmptySrcGrp.Replace($t2, "")
	$afterField = ([regex]::Matches($t2, [regex]::Escape($field))).Count
	$afterEmpty = ([regex]::Matches($t2, [regex]::Escape($elSource) + '\s[^>]*' + [regex]::Escape($attrName) + '=""')).Count
	if ($t2 -ne $t) {
		Save-RulesXmlAtomic -Path $path -Content $t2 -MinRatioOfOriginal 50
	}
	[void]$report.AppendLine(("FILE={0} removedProp={1} removedGrp={2} emptySrc {3}->{4} fieldRegUchet {5}->{6} changed={7}" -f `
		(Split-Path $path -Leaf), $nProp, $nGrp, $beforeEmpty, $afterEmpty, $beforeField, $afterField, ($t2 -ne $t)))
}

$report = New-Object System.Text.StringBuilder
[void]$report.AppendLine("=== Remove empty-source PKS ===")
[void]$report.AppendLine((Get-Date).ToString("s"))

# 1) remix
$remix = "E:\1C\AY\BPLM-UHLM-XML\BPLM-UH33LM_remix.xml"
Remove-EmptySourceProps $remix $report

# 2) current zip: extract / fix / rebuild
$zipCandidate = Get-ChildItem -LiteralPath "E:\1C\AY\BPLM-UHLM-XML" -Filter "*.zip" |
	Where-Object { $_.Name -like "*3.0.201.16*3.3.3.48.zip" -and $_.Name -notlike "*.bak*" -and $_.Name -notlike "*remix*" } |
	Sort-Object LastWriteTime -Descending |
	Select-Object -First 1
if (-not $zipCandidate) { throw "zip not found" }
$zip = $zipCandidate.FullName
[void]$report.AppendLine("ZIP=$zip")

$work = Join-Path $OutDir "_rules-remove-empty-src"
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
New-Item -ItemType Directory -Path $work | Out-Null
[IO.Compression.ZipFile]::ExtractToDirectory($zip, $work)

foreach ($name in @("ExchangeRules.xml", "CorrespondentExchangeRules.xml")) {
	Remove-EmptySourceProps (Join-Path $work $name) $report
}

$bakZip = $zip + ".bak-before-remove-empty-src"
if (-not (Test-Path -LiteralPath $bakZip)) {
	Copy-Item -LiteralPath $zip -Destination $bakZip
}
Remove-Item -LiteralPath $zip -Force
[IO.Compression.ZipFile]::CreateFromDirectory($work, $zip, [IO.Compression.CompressionLevel]::Optimal, $false)
[void]$report.AppendLine(("ZIP_REBUILT size={0}" -f (Get-Item -LiteralPath $zip).Length))

$repPath = Join-Path $OutDir "_remove-empty-src-report.txt"
[IO.File]::WriteAllText($repPath, $report.ToString(), $utf8)
Write-Host $report.ToString()
Write-Host "REPORT: $repPath"
exit 0
