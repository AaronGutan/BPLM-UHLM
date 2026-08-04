$ErrorActionPreference = 'Stop'
function U([int[]]$Codes) {
	$sb = New-Object System.Text.StringBuilder
	foreach ($c in $Codes) { [void]$sb.Append([char]$c) }
	return $sb.ToString()
}
$Suffix = U @(0x041F,0x0440,0x0438,0x0441,0x043E,0x0435,0x0434,0x0438,0x043D,0x0435,0x043D,0x043D,0x044B,0x0435,0x0424,0x0430,0x0439,0x043B,0x044B)
$CatRef = U @(0x0421,0x043F,0x0440,0x0430,0x0432,0x043E,0x0447,0x043D,0x0438,0x043A,0x0421,0x0441,0x044B,0x043B,0x043A,0x0430)
$SampleObj = U @(0x041E,0x0431,0x044A,0x0435,0x043A,0x0442,0x0412,0x044B,0x0431,0x043E,0x0440,0x043A,0x0438)
$Source = U @(0x0418,0x0441,0x0442,0x043E,0x0447,0x043D,0x0438,0x043A)
$ConvCode = U @(0x041A,0x043E,0x0434,0x041F,0x0440,0x0430,0x0432,0x0438,0x043B,0x0430,0x041A,0x043E,0x043D,0x0432,0x0435,0x0440,0x0442,0x0430,0x0446,0x0438,0x0438)
$marker = 'ATTACHED_FILES_EXCLUDED'

$path = 'E:\1C\AY\BPLM-UHLM-XML\BPLM-UH33LM_remix.xml'
$t = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)

$r = New-Object System.Text.StringBuilder
[void]$r.AppendLine('FINAL CHECK')
[void]$r.AppendLine('PCO Source CatRef*Suffix: ' + ([regex]::Matches($t, '<' + $Source + '>' + [regex]::Escape($CatRef) + '\.\w*' + [regex]::Escape($Suffix) + '</')).Count)
[void]$r.AppendLine('PVD SampleObj CatRef*Suffix: ' + ([regex]::Matches($t, '<' + $SampleObj + '>' + [regex]::Escape($CatRef) + '\.\w*' + [regex]::Escape($Suffix) + '</')).Count)
[void]$r.AppendLine('ConvCode *Suffix (any): ' + ([regex]::Matches($t, '<' + $ConvCode + '>\w*' + [regex]::Escape($Suffix))).Count)
[void]$r.AppendLine('BeforeUnload marker: ' + $t.Contains($marker))
[void]$r.AppendLine('File length: ' + $t.Length)
$out = 'E:\1C\AY\BPLM-UHLM-XML\.tasks\_exclude-attached-files-report.txt'
[IO.File]::AppendAllText($out, $r.ToString(), [Text.Encoding]::UTF8)
Write-Host $r.ToString()
