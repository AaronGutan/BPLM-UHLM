# Find remaining empty-source patterns that remover missed
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
function U([string]$s) {
	return [regex]::Replace($s, '\\u([0-9A-Fa-f]{4})', {
		param($m)
		return [string][char][Convert]::ToInt32($m.Groups[1].Value, 16)
	})
}
$src = U('\u0418\u0441\u0442\u043e\u0447\u043d\u0438\u043a')
$name = U('\u0418\u043c\u044f')
$prop = U('\u0421\u0432\u043e\u0439\u0441\u0442\u0432\u043e')
$grp = U('\u0413\u0440\u0443\u043f\u043f\u0430')
$field = U('\u0418\u0441\u043f\u043e\u043b\u044c\u0437\u043e\u0432\u0430\u0442\u044c\u0412\u0420\u0435\u0433\u043b\u0430\u043c\u0435\u043d\u0442\u0438\u0440\u043e\u0432\u0430\u043d\u043d\u043e\u043c\u0423\u0447\u0435\u0442\u0435')

$path = 'E:\1C\AY\BPLM-UHLM-XML\BPLM-UH33LM_remix.xml'
$t = [IO.File]::ReadAllText($path)
$rx = [regex]('<' + [regex]::Escape($src) + '\s[^>]*' + [regex]::Escape($name) + '=""[^>]*>')
$ms = $rx.Matches($t)
Write-Host ("remaining emptySrc tags={0}" -f $ms.Count)
$sb = New-Object System.Text.StringBuilder
$i = 0
foreach ($m in $ms) {
	$i++
	$from = [Math]::Max(0, $m.Index - 250)
	$len = [Math]::Min(700, $t.Length - $from)
	[void]$sb.AppendLine(("=== {0} at {1} ===" -f $i, $m.Index))
	[void]$sb.AppendLine($t.Substring($from, $len))
	[void]$sb.AppendLine()
}
$out = Join-Path $here '_remaining-empty-src.txt'
[IO.File]::WriteAllText($out, $sb.ToString(), (New-Object Text.UTF8Encoding $false))
Write-Host ("wrote {0}" -f $out)
Write-Host ("field count={0}" -f ([regex]::Matches($t, [regex]::Escape($field))).Count)
