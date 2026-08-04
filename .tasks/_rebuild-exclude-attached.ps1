$ErrorActionPreference = 'Stop'
function U([int[]]$Codes) {
	$sb = New-Object System.Text.StringBuilder
	foreach ($c in $Codes) { [void]$sb.Append([char]$c) }
	return $sb.ToString()
}

$Suffix = U @(0x041F,0x0440,0x0438,0x0441,0x043E,0x0435,0x0434,0x0438,0x043D,0x0435,0x043D,0x043D,0x044B,0x0435,0x0424,0x0430,0x0439,0x043B,0x044B)
$CatRef = U @(0x0421,0x043F,0x0440,0x0430,0x0432,0x043E,0x0447,0x043D,0x0438,0x043A,0x0421,0x0441,0x044B,0x043B,0x043A,0x0430)
$Rule = U @(0x041F,0x0440,0x0430,0x0432,0x0438,0x043B,0x043E)
$Source = U @(0x0418,0x0441,0x0442,0x043E,0x0447,0x043D,0x0438,0x043A)
$ConvCode = U @(0x041A,0x043E,0x0434,0x041F,0x0440,0x0430,0x0432,0x0438,0x043B,0x0430,0x041A,0x043E,0x043D,0x0432,0x0435,0x0440,0x0442,0x0430,0x0446,0x0438,0x0438)
$SampleObj = U @(0x041E,0x0431,0x044A,0x0435,0x043A,0x0442,0x0412,0x044B,0x0431,0x043E,0x0440,0x043A,0x0438)
$DisableAttr = ' ' + (U @(0x041E,0x0442,0x043A,0x043B,0x044E,0x0447,0x0438,0x0442,0x044C)) + '="false"'
$BeforeUnload = U @(0x041F,0x0435,0x0440,0x0435,0x0434,0x0412,0x044B,0x0433,0x0440,0x0443,0x0437,0x043A,0x043E,0x0439,0x041E,0x0431,0x044A,0x0435,0x043A,0x0442,0x0430)
$RootClose = '</' + (U @(0x041F,0x0440,0x0430,0x0432,0x0438,0x043B,0x0430,0x041E,0x0431,0x043C,0x0435,0x043D,0x0430)) + '>'

$If = U @(0x0415,0x0441,0x043B,0x0438)
$Then = U @(0x0422,0x043E,0x0433,0x0434,0x0430)
$EndIf = U @(0x041A,0x043E,0x043D,0x0435,0x0446,0x0415,0x0441,0x043B,0x0438)
$And = U @(0x0418)
$Not = U @(0x041D,0x0435)
$Undefined = U @(0x041D,0x0435,0x043E,0x043F,0x0440,0x0435,0x0434,0x0435,0x043B,0x0435,0x043D,0x043E)
$Metadata = U @(0x041C,0x0435,0x0442,0x0430,0x0434,0x0430,0x043D,0x043D,0x044B,0x0435)
$FindByType = U @(0x041D,0x0430,0x0439,0x0442,0x0438,0x041F,0x043E,0x0422,0x0438,0x043F,0x0443)
$TypeOf = U @(0x0422,0x0438,0x043F,0x0417,0x043D,0x0447)
$Object = U @(0x041E,0x0431,0x044A,0x0435,0x043A,0x0442)
$Catalogs = U @(0x0421,0x043F,0x0440,0x0430,0x0432,0x043E,0x0447,0x043D,0x0438,0x043A,0x0438)
$Contains = U @(0x0421,0x043E,0x0434,0x0435,0x0440,0x0436,0x0438,0x0442)
$Right = U @(0x041F,0x0440,0x0430,0x0432)
$Name = U @(0x0418,0x043C,0x044F)
$Cancel = U @(0x041E,0x0442,0x043A,0x0430,0x0437)
$TrueVal = U @(0x0418,0x0441,0x0442,0x0438,0x043D,0x0430)
$MdVar = U @(0x041C,0x0414)

$path = 'E:\1C\AY\BPLM-UHLM-XML\BPLM-UH33LM_remix.xml'
$bak = $path + '.bak-before-exclude-attached-files'
$report = 'E:\1C\AY\BPLM-UHLM-XML\.tasks\_exclude-attached-files-report.txt'
$marker = 'ATTACHED_FILES_EXCLUDED'
$utf8 = New-Object Text.UTF8Encoding $false

if (-not (Test-Path -LiteralPath $bak)) { throw 'Backup not found: ' + $bak }

Write-Host 'Restoring from backup...'
Copy-Item -LiteralPath $bak -Destination $path -Force
$bakSize = (Get-Item -LiteralPath $bak).Length
Write-Host ('Backup size: ' + $bakSize)

Write-Host 'Reading...'
$text = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
$origLen = $text.Length
Write-Host ('Length: ' + $origLen)
if (-not $text.Contains($RootClose)) { throw 'Backup missing root close tag' }

# 1) Remove PCO
$pcoRx = [regex]::new(
	'(?s)\t{3}<' + $Rule + '>\r?\n(?:(?!\t{3}</' + $Rule + '>).)*?\t{4}<' + $Source + '>' +
	[regex]::Escape($CatRef) + '\.\w*' + [regex]::Escape($Suffix) + '</' + $Source + '>\r?\n' +
	'(?:(?!\t{3}</' + $Rule + '>).)*?\t{3}</' + $Rule + '>\r?\n'
)
$pcoCount = $pcoRx.Matches($text).Count
Write-Host ('PCO remove: ' + $pcoCount)
$text = $pcoRx.Replace($text, '')

# 2) Remove PVD (ОбъектВыборки = СправочникСсылка.*Suffix)
$pvdRx = [regex]::new(
	'(?s)\t{3}<' + $Rule + $DisableAttr + '>\r?\n(?:(?!\t{3}</' + $Rule + '>).)*?\t{4}<' + $SampleObj + '>' +
	[regex]::Escape($CatRef) + '\.\w*' + [regex]::Escape($Suffix) + '</' + $SampleObj + '>\r?\n' +
	'(?:(?!\t{3}</' + $Rule + '>).)*?\t{3}</' + $Rule + '>\r?\n'
)
$pvdCount = $pvdRx.Matches($text).Count
Write-Host ('PVD remove: ' + $pvdCount)
$text = $pvdRx.Replace($text, '')

# 3) Remove ConvCode refs ONLY for catalog rules: pattern with CatRef not needed;
#    skip register УдалитьПрисоединенныеФайлы by requiring code that is NOT starting with Удалить
# Safer: remove ConvCode lines where value matches \w*Suffix but not exactly Удалить+Suffix
$DeletePrefix = U @(0x0423,0x0434,0x0430,0x043B,0x0438,0x0442,0x044C)
$convRx = [regex]::new(
	'\r?\n\t+<' + $ConvCode + '>(?!' + [regex]::Escape($DeletePrefix) + ')\w*' + [regex]::Escape($Suffix) + '\s*</' + $ConvCode + '>'
)
$convCount = $convRx.Matches($text).Count
Write-Host ('ConvCode remove: ' + $convCount)
$text = $convRx.Replace($text, '')

# 4) Patch BeforeUnload WITHOUT <> (XML-safe)
$nl = "`r`n"
$bsl = ''
$bsl += $MdVar + ' = ' + $Metadata + '.' + $FindByType + '(' + $TypeOf + '(' + $Object + '));' + $nl
$bsl += $If + ' ' + $Not + ' (' + $MdVar + ' = ' + $Undefined + ') ' + $And + ' ' + $Metadata + '.' + $Catalogs + '.' + $Contains + '(' + $MdVar + ') ' + $Then + $nl
$bsl += "`t" + $If + ' ' + $Right + '(' + $MdVar + '.' + $Name + ', ' + $Suffix.Length + ') = "' + $Suffix + '" ' + $Then + $nl
$bsl += "`t`t" + $Cancel + ' = ' + $TrueVal + ';' + $nl
$bsl += "`t" + $EndIf + ';' + $nl
$bsl += $EndIf + ';' + $nl

$beforeRx = [regex]::new('(<' + $BeforeUnload + '>)(.*?)(</' + $BeforeUnload + '>)', [Text.RegularExpressions.RegexOptions]::Singleline)
$beforeM = $beforeRx.Match($text)
if (-not $beforeM.Success) { throw 'BeforeUnload not found' }
if ($beforeM.Groups[2].Value.Contains($marker)) {
	Write-Host 'BeforeUnload already patched'
} else {
	$newInner = '//' + $marker + $nl + $bsl + $beforeM.Groups[2].Value
	$replacement = $beforeM.Groups[1].Value + $newInner + $beforeM.Groups[3].Value
	$text = $text.Remove($beforeM.Index, $beforeM.Length).Insert($beforeM.Index, $replacement)
	Write-Host 'BeforeUnload patched (XML-safe, no angle brackets)'
}

# Validate
if (-not $text.Contains($RootClose)) { throw 'Root close tag lost after edits' }
$closeCount = ([regex]::Matches($text, [regex]::Escape($RootClose))).Count
$openCount = ([regex]::Matches($text, '<' + (U @(0x041F,0x0440,0x0430,0x0432,0x0438,0x043B,0x0430,0x041E,0x0431,0x043C,0x0435,0x043D,0x0430)) + '>')).Count
Write-Host ('Root open=' + $openCount + ' close=' + $closeCount)
if ($openCount -ne 1 -or $closeCount -ne 1) { throw 'Invalid root tag count' }

$leftPco = ([regex]::Matches($text, '<' + $Source + '>' + [regex]::Escape($CatRef) + '\.\w*' + [regex]::Escape($Suffix) + '</')).Count
$leftPvd = ([regex]::Matches($text, '<' + $SampleObj + '>' + [regex]::Escape($CatRef) + '\.\w*' + [regex]::Escape($Suffix) + '</')).Count
Write-Host ('Left PCO=' + $leftPco + ' PVD=' + $leftPvd)
Write-Host ('New length: ' + $text.Length + ' delta=' + ($text.Length - $origLen))

# Ensure no raw <> in BeforeUnload
$bu = $beforeRx.Match($text).Groups[2].Value
if ($bu.Contains('<') -or $bu.Contains('>')) {
	# allow only if escaped - check raw
	if ($bu -match '(?<!&lt;)<(?!/)|(?<!&gt;)>(?!;)') {
		Write-Host 'WARNING: angle brackets still in BeforeUnload'
	}
}
if ($bu.Contains('<>')) { throw 'Raw <> still present in BeforeUnload' }

Write-Host 'Writing full file...'
[IO.File]::WriteAllText($path, $text, $utf8)
$newSize = (Get-Item -LiteralPath $path).Length
Write-Host ('Written size: ' + $newSize)

$rep = "REBUILD OK`r`nPCO=$pcoCount PVD=$pvdCount Conv=$convCount`r`nSize=$newSize LeftPCO=$leftPco LeftPVD=$leftPvd`r`n"
[IO.File]::WriteAllText($report, $rep, [Text.Encoding]::UTF8)
Write-Host 'DONE'
