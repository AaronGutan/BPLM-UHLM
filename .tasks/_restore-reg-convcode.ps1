$ErrorActionPreference = 'Stop'
function U([int[]]$Codes) {
	$sb = New-Object System.Text.StringBuilder
	foreach ($c in $Codes) { [void]$sb.Append([char]$c) }
	return $sb.ToString()
}
$Name = U @(0x0423,0x0434,0x0430,0x043B,0x0438,0x0442,0x044C,0x041F,0x0440,0x0438,0x0441,0x043E,0x0435,0x0434,0x0438,0x043D,0x0435,0x043D,0x043D,0x044B,0x0435,0x0424,0x0430,0x0439,0x043B,0x044B)
$ConvCode = U @(0x041A,0x043E,0x0434,0x041F,0x0440,0x0430,0x0432,0x0438,0x043B,0x0430,0x041A,0x043E,0x043D,0x0432,0x0435,0x0440,0x0442,0x0430,0x0446,0x0438,0x0438)
$Order = U @(0x041F,0x043E,0x0440,0x044F,0x0434,0x043E,0x043A)
$Method = U @(0x0421,0x043F,0x043E,0x0441,0x043E,0x0431,0x041E,0x0442,0x0431,0x043E,0x0440,0x0430,0x0414,0x0430,0x043D,0x043D,0x044B,0x0445)
$Kod = U @(0x041A,0x043E,0x0434)
$Naz = U @(0x041D,0x0430,0x0438,0x043C,0x0435,0x043D,0x043E,0x0432,0x0430,0x043D,0x0438,0x0435)

$path = 'E:\1C\AY\BPLM-UHLM-XML\BPLM-UH33LM_remix.xml'
$text = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)

$rx = [regex]::new(
	'(<' + $Kod + '>' + [regex]::Escape($Name) + '</' + $Kod + '>\r?\n\t{4}<' + $Naz + '>' + [regex]::Escape($Name) + '</' + $Naz + '>\r?\n\t{4}<' + $Order + '>58700</' + $Order + '>)\r?\n(\t{4}<' + $Method + '>)'
)
Write-Host ('Matches: ' + $rx.Matches($text).Count)
if ($rx.Matches($text).Count -ne 1) {
	$idx = $text.IndexOf('<' + $Kod + '>' + $Name + '</' + $Kod + '>')
	Write-Host ('First Kod index: ' + $idx)
	if ($idx -ge 0) { Write-Host ($text.Substring($idx, [Math]::Min(400, $text.Length - $idx))) }
	throw 'unexpected match count'
}

$text2 = $rx.Replace($text, {
	param($m)
	return $m.Groups[1].Value + "`r`n`t`t`t`t<" + $ConvCode + '>' + $Name.PadRight(50) + '</' + $ConvCode + ">`r`n" + $m.Groups[2].Value
}, 1)

[IO.File]::WriteAllText($path, $text2, (New-Object Text.UTF8Encoding $false))
Write-Host ('Restored ConvCode, new len=' + $text2.Length)
