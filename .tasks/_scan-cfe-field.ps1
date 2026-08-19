# ASCII check CFE templates for problem field
$ErrorActionPreference = 'Stop'
function U([string]$s) {
	return [regex]::Replace($s, '\\u([0-9A-Fa-f]{4})', {
		param($m)
		return [string][char][Convert]::ToInt32($m.Groups[1].Value, 16)
	})
}
$field = U('\u0418\u0441\u043f\u043e\u043b\u044c\u0437\u043e\u0432\u0430\u0442\u044c\u0412\u0420\u0435\u0433\u043b\u0430\u043c\u0435\u043d\u0442\u0438\u0440\u043e\u0432\u0430\u043d\u043d\u043e\u043c\u0423\u0447\u0435\u0442\u0435')
$root = 'E:\1C\AY\BPLM-UHLM-XML\acclmcopy-cfe-consolidation'
Get-ChildItem -LiteralPath $root -Recurse -Filter 'Template.txt' -ErrorAction SilentlyContinue | ForEach-Object {
	$t = [IO.File]::ReadAllText($_.FullName)
	$c = ([regex]::Matches($t, [regex]::Escape($field))).Count
	if ($c -gt 0 -or $_.Length -gt 500000) {
		Write-Host ("{0} size={1} field={2}" -f $_.FullName.Substring($root.Length), $_.Length, $c)
	}
}
