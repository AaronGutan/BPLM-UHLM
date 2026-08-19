# ASCII-only scan
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here 'RulesXml-SafeWrite.ps1')

function U([string]$s) {
	return [regex]::Replace($s, '\\u([0-9A-Fa-f]{4})', {
		param($m)
		return [string][char][Convert]::ToInt32($m.Groups[1].Value, 16)
	})
}

$field = U('\u0418\u0441\u043f\u043e\u043b\u044c\u0437\u043e\u0432\u0430\u0442\u044c\u0412\u0420\u0435\u0433\u043b\u0430\u043c\u0435\u043d\u0442\u0438\u0440\u043e\u0432\u0430\u043d\u043d\u043e\u043c\u0423\u0447\u0435\u0442\u0435')
$src = U('\u0418\u0441\u0442\u043e\u0447\u043d\u0438\u043a')
$name = U('\u0418\u043c\u044f')
$prop = U('\u0421\u0432\u043e\u0439\u0441\u0442\u0432\u043e')
$tipOrg = U('\u0422\u0438\u043f\u041e\u0440\u0433\u0430\u043d\u0438\u0437\u0430\u0446\u0438\u0438')
$rules = U('\u041f\u0440\u0430\u0432\u0438\u043b\u0430\u041e\u0431\u043c\u0435\u043d\u0430')
$close = '</' + $rules + '>'
$emptySrc = $src + ' ' + $name + '=""'

$rxEmptySrcProp = [regex](
	'(?s)\s*<' + [regex]::Escape($prop) + '(?:\s[^>]*)?>' +
	'(?:(?!<' + [regex]::Escape($prop) + '(?:\s|>)).)*?' +
	'<' + [regex]::Escape($src) + '\s[^>]*\b' + [regex]::Escape($name) + '=""[^>/]*/?>' +
	'(?:(?!<' + [regex]::Escape($prop) + '(?:\s|>)).)*?' +
	'</' + [regex]::Escape($prop) + '>'
)

function Scan-Text([string]$label, [string]$t) {
	$c1 = ([regex]::Matches($t, [regex]::Escape($field))).Count
	$c2 = ([regex]::Matches($t, [regex]::Escape($emptySrc))).Count
	$c3 = ([regex]::Matches($t, [regex]::Escape($tipOrg))).Count
	$c4 = $rxEmptySrcProp.Matches($t).Count
	$endOk = $t.TrimEnd().EndsWith($close)
	Write-Host ("{0}: len={1} field={2} emptySrcLit={3} emptySrcBlocks={4} tipOrg={5} endOK={6}" -f `
		$label, $t.Length, $c1, $c2, $c4, $c3, $endOk)
	if ($c1 -gt 0) {
		$idx = $t.IndexOf($field)
		$from = [Math]::Max(0, $idx - 350)
		$len = [Math]::Min(900, $t.Length - $from)
		$snippet = $t.Substring($from, $len)
		$out = Join-Path $here '_scan-reg-uchete-snippet.txt'
		[IO.File]::WriteAllText($out, ("LABEL={0}`r`n{1}" -f $label, $snippet), (New-Object Text.UTF8Encoding $false))
		Write-Host ("  snippet -> {0}" -f $out)
		# does enclosing property match empty-src remover?
		$around = $t.Substring([Math]::Max(0, $idx - 2000), [Math]::Min(4000, $t.Length - [Math]::Max(0, $idx - 2000)))
		$m = $rxEmptySrcProp.Matches($around)
		Write-Host ("  emptySrcBlocks near field in window: {0}" -f $m.Count)
		foreach ($mm in $m) {
			if ($mm.Value.Contains($field)) {
				Write-Host ("  MATCHED block len={0}" -f $mm.Value.Length)
				[IO.File]::WriteAllText((Join-Path $here '_scan-reg-uchete-block.txt'), $mm.Value, (New-Object Text.UTF8Encoding $false))
			}
		}
	}
}

$root = 'E:\1C\AY\BPLM-UHLM-XML'
$paths = @(
	(Join-Path $root 'BPLM-UH33LM_remix.xml'),
	(Join-Path $here '_rules-remove-empty-src\ExchangeRules.xml'),
	(Join-Path $here '_zip-rules-clean\ExchangeRules.xml'),
	(Join-Path $here '_zip-rules-build\ExchangeRules.xml')
)
foreach ($p in $paths) {
	if (-not (Test-Path -LiteralPath $p)) { Write-Host ("MISSING {0}" -f $p); continue }
	Scan-Text (Split-Path $p -Leaf) ([IO.File]::ReadAllText($p))
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zipCandidate = Get-ChildItem -LiteralPath $root -Filter '*.zip' |
	Where-Object { $_.Name -like '*3.0.201.16*3.3.3.48.zip' -and $_.Name -notlike '*.bak*' -and $_.Name -notlike '*remix*' } |
	Sort-Object LastWriteTime -Descending |
	Select-Object -First 1
if (-not $zipCandidate) { throw 'zip not found' }
Write-Host ("ZIP={0}" -f $zipCandidate.FullName)
$z = [IO.Compression.ZipFile]::OpenRead($zipCandidate.FullName)
Write-Host ("ZIP entries={0}" -f $z.Entries.Count)
foreach ($e in $z.Entries) {
	Write-Host ("  entry: {0} ({1})" -f $e.FullName, $e.Length)
	if ($e.Name -notmatch 'ExchangeRules|Correspondent') { continue }
	$sr = New-Object IO.StreamReader($e.Open())
	$t = $sr.ReadToEnd(); $sr.Close()
	Scan-Text ('ZIP:' + $e.Name) $t
}
$z.Dispose()
