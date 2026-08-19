# Fix remaining empty-source groups + TipOrganizacii; rebuild zips; sync CFE templates.
# ASCII-only for Windows PowerShell 5.1.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = 'E:\1C\AY\BPLM-UHLM-XML'
. (Join-Path $here 'RulesXml-SafeWrite.ps1')

function U([string]$s) {
	return [regex]::Replace($s, '\\u([0-9A-Fa-f]{4})', {
		param($m)
		return [string][char][Convert]::ToInt32($m.Groups[1].Value, 16)
	})
}

$elProp = U('\u0421\u0432\u043e\u0439\u0441\u0442\u0432\u043e')
$elGrp = U('\u0413\u0440\u0443\u043f\u043f\u0430')
$elSource = U('\u0418\u0441\u0442\u043e\u0447\u043d\u0438\u043a')
$elDest = U('\u041f\u0440\u0438\u0435\u043c\u043d\u0438\u043a')
$attrName = U('\u0418\u043c\u044f')
$tipOrg = U('\u0422\u0438\u043f\u041e\u0440\u0433\u0430\u043d\u0438\u0437\u0430\u0446\u0438\u0438')
$field = U('\u0418\u0441\u043f\u043e\u043b\u044c\u0437\u043e\u0432\u0430\u0442\u044c\u0412\u0420\u0435\u0433\u043b\u0430\u043c\u0435\u043d\u0442\u0438\u0440\u043e\u0432\u0430\u043d\u043d\u043e\u043c\u0423\u0447\u0435\u0442\u0435')
$ankety = U('\u0410\u043d\u043a\u0435\u0442\u044b\u041f\u043e\u0441\u0442\u0430\u0432\u0449\u0438\u043a\u043e\u0432')
$vyplaty = U('\u0412\u044b\u043f\u043b\u0430\u0442\u044b\u0418\u041f\u043e\u0441\u043e\u0431\u0438\u044f')
$tipyOrg = U('\u0422\u0438\u043f\u044b\u041e\u0440\u0433\u0430\u043d\u0438\u0437\u0430\u0446\u0438\u043e\u043d\u043d\u044b\u0445\u0415\u0434\u0438\u043d\u0438\u0446')
$utf8 = New-Object System.Text.UTF8Encoding $false
$report = New-Object System.Text.StringBuilder
[void]$report.AppendLine('=== Fix reg-uchete leftover + rebuild ===')
[void]$report.AppendLine((Get-Date).ToString('s'))

# Empty-source leaf groups (no nested Prop/Group)
$rxEmptyGrp = [regex](
	'(?s)\s*<' + [regex]::Escape($elGrp) + '(?:\s[^>]*)?>' +
	'(?:(?!<' + [regex]::Escape($elGrp) + '(?:\s|>))(?!<' + [regex]::Escape($elProp) + '(?:\s|>)).)*?' +
	'<' + [regex]::Escape($elSource) + '\s[^>]*\b' + [regex]::Escape($attrName) + '=""[^>/]*/?>' +
	'(?:(?!<' + [regex]::Escape($elGrp) + '(?:\s|>))(?!<' + [regex]::Escape($elProp) + '(?:\s|>)).)*?' +
	'</' + [regex]::Escape($elGrp) + '>'
)
$rxEmptyProp = [regex](
	'(?s)\s*<' + [regex]::Escape($elProp) + '(?:\s[^>]*)?>' +
	'(?:(?!<' + [regex]::Escape($elProp) + '(?:\s|>)).)*?' +
	'<' + [regex]::Escape($elSource) + '\s[^>]*\b' + [regex]::Escape($attrName) + '=""[^>/]*/?>' +
	'(?:(?!<' + [regex]::Escape($elProp) + '(?:\s|>)).)*?' +
	'</' + [regex]::Escape($elProp) + '>'
)
$rxTipOrg = [regex](
	'(?s)\s*<' + [regex]::Escape($elProp) + '(?:\s[^>]*)?>' +
	'(?:(?!<' + [regex]::Escape($elProp) + '(?:\s|>)).)*?' +
	'<' + [regex]::Escape($elDest) + '\s[^>]*\b' + [regex]::Escape($attrName) + '="' + [regex]::Escape($tipOrg) + '"[^/]*/>' +
	'(?:(?!<' + [regex]::Escape($elProp) + '(?:\s|>)).)*?' +
	'</' + [regex]::Escape($elProp) + '>'
)

function Clean-RulesText([string]$t) {
	$nProp = $rxEmptyProp.Matches($t).Count
	$t = $rxEmptyProp.Replace($t, '')
	$nGrp = $rxEmptyGrp.Matches($t).Count
	$t = $rxEmptyGrp.Replace($t, '')
	$nTip = $rxTipOrg.Matches($t).Count
	$t = $rxTipOrg.Replace($t, '')
	return @{ Text = $t; Prop = $nProp; Grp = $nGrp; Tip = $nTip }
}

function Assert-Clean([string]$label, [string]$t) {
	$cField = ([regex]::Matches($t, [regex]::Escape($field))).Count
	$cEmpty = ([regex]::Matches($t, [regex]::Escape($elSource) + '\s[^>]*' + [regex]::Escape($attrName) + '=""')).Count
	$cTip = ([regex]::Matches($t, [regex]::Escape($tipOrg))).Count
	$cAnk = ([regex]::Matches($t, [regex]::Escape($ankety))).Count
	$cVyp = ([regex]::Matches($t, [regex]::Escape($vyplaty))).Count
	$cTipy = ([regex]::Matches($t, [regex]::Escape($tipyOrg))).Count
	$line = ("CHECK {0}: field={1} emptySrc={2} tipOrg={3} ankety={4} vyplaty={5} tipyOrg={6}" -f `
		$label, $cField, $cEmpty, $cTip, $cAnk, $cVyp, $cTipy)
	[void]$report.AppendLine($line)
	Write-Host $line
	if ($cField -ne 0 -or $cEmpty -ne 0 -or $cTip -ne 0) {
		throw ("Not clean: {0}" -f $line)
	}
}

# 1) remix
$remix = Join-Path $root 'BPLM-UH33LM_remix.xml'
$t = [IO.File]::ReadAllText($remix, $utf8)
$r = Clean-RulesText $t
[void]$report.AppendLine(("REMIX removed prop={0} grp={1} tipOrg={2}" -f $r.Prop, $r.Grp, $r.Tip))
Save-RulesXmlAtomic -Path $remix -Content $r.Text -MinRatioOfOriginal 50
Assert-Clean 'remix' ([IO.File]::ReadAllText($remix, $utf8))
$cleanRules = [IO.File]::ReadAllText($remix, $utf8)

# 2) work dir for zip pack
$work = Join-Path $here '_zip-rules-clean'
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
New-Item -ItemType Directory -Path $work | Out-Null

# RegistrationRules from current БПКОРП zip
$bpZip = Get-ChildItem -LiteralPath $root -Filter '*.zip' |
	Where-Object { $_.Name -like '*3.0.201.16*3.3.3.48.zip' -and $_.Name -notlike '*.bak*' -and $_.Name -notlike '*remix*' } |
	Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $bpZip) { throw 'BPKORP zip not found' }
$tmpExtract = Join-Path $here '_zip-tmp-extract'
if (Test-Path $tmpExtract) { Remove-Item $tmpExtract -Recurse -Force }
New-Item -ItemType Directory -Path $tmpExtract | Out-Null
[IO.Compression.ZipFile]::ExtractToDirectory($bpZip.FullName, $tmpExtract)
Copy-Item (Join-Path $tmpExtract 'RegistrationRules.xml') (Join-Path $work 'RegistrationRules.xml') -Force
Remove-Item $tmpExtract -Recurse -Force

# Write Exchange + Correspondent from clean remix (Correspondent = same content per HOWTO)
[IO.File]::WriteAllText((Join-Path $work 'ExchangeRules.xml'), $cleanRules, $utf8)
[IO.File]::WriteAllText((Join-Path $work 'CorrespondentExchangeRules.xml'), $cleanRules, $utf8)
Assert-Clean 'work-Exchange' $cleanRules

function Rebuild-Zip([string]$zipPath) {
	$bak = $zipPath + '.bak-before-reg-uchete-fix'
	if ((Test-Path -LiteralPath $zipPath) -and -not (Test-Path -LiteralPath $bak)) {
		Copy-Item -LiteralPath $zipPath -Destination $bak
	}
	if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
	[IO.Compression.ZipFile]::CreateFromDirectory($work, $zipPath, [IO.Compression.CompressionLevel]::Optimal, $false)
	$z = [IO.Compression.ZipFile]::OpenRead($zipPath)
	$names = @($z.Entries | ForEach-Object { $_.FullName })
	$z.Dispose()
	[void]$report.AppendLine(("ZIP {0} count={1} entries={2}" -f $zipPath, $names.Count, ($names -join ',')))
	Write-Host ("ZIP rebuilt: {0} entries={1}" -f $zipPath, $names.Count)
	if ($names.Count -ne 3) { throw 'zip must have exactly 3 entries' }
	if ($names -match '\.bak') { throw 'zip contains bak' }
}

Rebuild-Zip $bpZip.FullName
$remixZip = Join-Path $root 'BPLM-UH33LM_remix.zip'
Rebuild-Zip $remixZip

# 3) CFE templates (both slots = clean remix)
$cfeRoot = Join-Path $root 'acclmcopy-cfe-consolidation'
$tpls = Get-ChildItem -LiteralPath $cfeRoot -Recurse -Filter 'Template.txt' -ErrorAction SilentlyContinue |
	Where-Object { $_.FullName -match 'ExchangePlans' -and $_.Length -gt 1000000 }
foreach ($tpl in $tpls) {
	$bak = $tpl.FullName + '.bak-before-reg-uchete-fix'
	if (-not (Test-Path -LiteralPath $bak)) {
		Copy-Item -LiteralPath $tpl.FullName -Destination $bak
	}
	# Template.txt for exchange rules is plain XML text
	Save-RulesXmlAtomic -Path $tpl.FullName -Content $cleanRules -MinRatioOfOriginal 40
	Assert-Clean ('CFE:' + $tpl.Directory.Parent.Name) ([IO.File]::ReadAllText($tpl.FullName, $utf8))
	[void]$report.AppendLine(('CFE synced: ' + $tpl.FullName))
}

$repPath = Join-Path $here '_fix-reg-uchete-report.txt'
[IO.File]::WriteAllText($repPath, $report.ToString(), $utf8)
Write-Host $report.ToString()
Write-Host ("REPORT: {0}" -f $repPath)
exit 0
