# Remove PVD unload rules for catalogs СправочникСсылка.*ПрисоединенныеФайлы
$ErrorActionPreference = 'Stop'
function U([int[]]$Codes) {
	$sb = New-Object System.Text.StringBuilder
	foreach ($c in $Codes) { [void]$sb.Append([char]$c) }
	return $sb.ToString()
}
$Suffix = U @(0x041F,0x0440,0x0438,0x0441,0x043E,0x0435,0x0434,0x0438,0x043D,0x0435,0x043D,0x043D,0x044B,0x0435,0x0424,0x0430,0x0439,0x043B,0x044B)
$CatRef = U @(0x0421,0x043F,0x0440,0x0430,0x0432,0x043E,0x0447,0x043D,0x0438,0x043A,0x0421,0x0441,0x044B,0x043B,0x043A,0x0430)
$SampleObj = U @(0x041E,0x0431,0x044A,0x0435,0x043A,0x0442,0x0412,0x044B,0x0431,0x043E,0x0440,0x043A,0x0438)
$Rule = U @(0x041F,0x0440,0x0430,0x0432,0x0438,0x043B,0x043E)
$DisableAttr = ' ' + (U @(0x041E,0x0442,0x043A,0x043B,0x044E,0x0447,0x0438,0x0442,0x044C)) + '="false"'
$ConvCode = U @(0x041A,0x043E,0x0434,0x041F,0x0440,0x0430,0x0432,0x0438,0x043B,0x0430,0x041A,0x043E,0x043D,0x0432,0x0435,0x0440,0x0442,0x0430,0x0446,0x0438,0x0438)

$path = 'E:\1C\AY\BPLM-UHLM-XML\BPLM-UH33LM_remix.xml'
Write-Host 'Reading...'
$text = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
$orig = $text.Length

$pvdRx = [regex]::new(
	'(?s)\t{3}<' + $Rule + $DisableAttr + '>\r?\n(?:(?!\t{3}</' + $Rule + '>).)*?\t{4}<' + $SampleObj + '>' +
	[regex]::Escape($CatRef) + '\.\w*' + [regex]::Escape($Suffix) + '</' + $SampleObj + '>\r?\n' +
	'(?:(?!\t{3}</' + $Rule + '>).)*?\t{3}</' + $Rule + '>\r?\n'
)
$cnt = $pvdRx.Matches($text).Count
Write-Host ('PVD catalog rules to remove: ' + $cnt)
$text = $pvdRx.Replace($text, '')

$left = ([regex]::Matches($text, '<' + $SampleObj + '>' + [regex]::Escape($CatRef) + '\.\w*' + [regex]::Escape($Suffix))).Count
Write-Host ('Remaining SampleObj CatRef*Suffix: ' + $left)
Write-Host ('Delta: ' + ($text.Length - $orig))

Write-Host 'Writing...'
[IO.File]::WriteAllText($path, $text, (New-Object Text.UTF8Encoding $false))
Write-Host 'DONE'
