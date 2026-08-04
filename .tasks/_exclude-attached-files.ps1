# ASCII-only: exclude catalogs *PrisoedinennyeFaily from BPLM-UH33LM_remix.xml
[Console]::OutputEncoding = [Text.UTF8Encoding]::UTF8
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
$CatalogDot = U @(0x0421,0x043F,0x0440,0x0430,0x0432,0x043E,0x0447,0x043D,0x0438,0x043A,0x002E)
$BeforeUnload = U @(0x041F,0x0435,0x0440,0x0435,0x0434,0x0412,0x044B,0x0433,0x0440,0x0443,0x0437,0x043A,0x043E,0x0439,0x041E,0x0431,0x044A,0x0435,0x043A,0x0442,0x0430)
$DisableAttr = ' ' + (U @(0x041E,0x0442,0x043A,0x043B,0x044E,0x0447,0x0438,0x0442,0x044C)) + '="false"'

$If = U @(0x0415,0x0441,0x043B,0x0438)
$Then = U @(0x0422,0x043E,0x0433,0x0434,0x0430)
$EndIf = U @(0x041A,0x043E,0x043D,0x0435,0x0446,0x0415,0x0441,0x043B,0x0438)
$And = U @(0x0418)
$NotEq = '<>'
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
$backup = $path + '.bak-before-exclude-attached-files'
$report = 'E:\1C\AY\BPLM-UHLM-XML\.tasks\_exclude-attached-files-report.txt'

Write-Host ('Suffix=' + $Suffix)
Write-Host 'Reading XML...'
$text = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
$origLen = $text.Length
Write-Host ('Original length: ' + $origLen)

$nameSet = New-Object 'System.Collections.Generic.HashSet[string]'
$rxName = [regex]::new([regex]::Escape($CatRef) + '\.(\w*' + [regex]::Escape($Suffix) + ')')
foreach ($m in $rxName.Matches($text)) { [void]$nameSet.Add($m.Groups[1].Value) }
$names = @($nameSet | Sort-Object)
Write-Host ('Unique catalogs: ' + $names.Count)

# 1) Remove PCO rules
$pcoRx = [regex]::new(
	'(?s)\t{3}<' + $Rule + '>\r?\n(?:(?!\t{3}</' + $Rule + '>).)*?\t{4}<' + $Source + '>' +
	[regex]::Escape($CatRef) + '\.\w*' + [regex]::Escape($Suffix) + '</' + $Source + '>\r?\n' +
	'(?:(?!\t{3}</' + $Rule + '>).)*?\t{3}</' + $Rule + '>\r?\n'
)
$pcoCount = $pcoRx.Matches($text).Count
Write-Host ('PCO rules: ' + $pcoCount)
$text = $pcoRx.Replace($text, '')

# 2) Remove PVD rules (tab3)
$pvdRx = [regex]::new(
	'(?s)\t{3}<' + $Rule + $DisableAttr + '>\r?\n(?:(?!\t{3}</' + $Rule + '>).)*?\t{4}<' + $SampleObj + '>' +
	[regex]::Escape($CatalogDot) + '\w*' + [regex]::Escape($Suffix) + '</' + $SampleObj + '>\r?\n' +
	'(?:(?!\t{3}</' + $Rule + '>).)*?\t{3}</' + $Rule + '>\r?\n'
)
$pvdCount = $pvdRx.Matches($text).Count
Write-Host ('PVD rules tab3: ' + $pvdCount)
$text = $pvdRx.Replace($text, '')

# PVD tab2
$pvdRx2 = [regex]::new(
	'(?s)\t{2}<' + $Rule + $DisableAttr + '>\r?\n(?:(?!\t{2}</' + $Rule + '>).)*?<' + $SampleObj + '>' +
	[regex]::Escape($CatalogDot) + '\w*' + [regex]::Escape($Suffix) + '</' + $SampleObj + '>\r?\n' +
	'(?:(?!\t{2}</' + $Rule + '>).)*?\t{2}</' + $Rule + '>\r?\n'
)
$pvdCount2 = $pvdRx2.Matches($text).Count
Write-Host ('PVD rules tab2: ' + $pvdCount2)
$text = $pvdRx2.Replace($text, '')

# 3) Remove КодПравилаКонвертации lines for those catalogs
$convRx = [regex]::new(
	'\r?\n\t+<' + $ConvCode + '>\w*' + [regex]::Escape($Suffix) + '\s*</' + $ConvCode + '>'
)
$convCount = $convRx.Matches($text).Count
Write-Host ('ConvCode refs: ' + $convCount)
$text = $convRx.Replace($text, '')

# 4) Prepend BeforeUnload filter
$nl = "`r`n"
$bsl = ''
$bsl += $MdVar + ' = ' + $Metadata + '.' + $FindByType + '(' + $TypeOf + '(' + $Object + '));' + $nl
$bsl += $If + ' ' + $MdVar + ' ' + $NotEq + ' ' + $Undefined + ' ' + $And + ' ' + $Metadata + '.' + $Catalogs + '.' + $Contains + '(' + $MdVar + ') ' + $Then + $nl
$bsl += "`t" + $If + ' ' + $Right + '(' + $MdVar + '.' + $Name + ', ' + $Suffix.Length + ') = "' + $Suffix + '" ' + $Then + $nl
$bsl += "`t`t" + $Cancel + ' = ' + $TrueVal + ';' + $nl
$bsl += "`t" + $EndIf + ';' + $nl
$bsl += $EndIf + ';' + $nl

$beforeRx = [regex]::new('(<' + $BeforeUnload + '>)(.*?)(</' + $BeforeUnload + '>)', [Text.RegularExpressions.RegexOptions]::Singleline)
$beforeM = $beforeRx.Match($text)
if (-not $beforeM.Success) { throw 'BeforeUnload not found' }
$marker = 'ATTACHED_FILES_EXCLUDED'
if ($beforeM.Groups[2].Value.Contains($marker)) {
	Write-Host 'BeforeUnload already patched'
} else {
	$newInner = '//' + $marker + $nl + $bsl + $beforeM.Groups[2].Value
	$replacement = $beforeM.Groups[1].Value + $newInner + $beforeM.Groups[3].Value
	$text = $text.Remove($beforeM.Index, $beforeM.Length).Insert($beforeM.Index, $replacement)
	Write-Host 'BeforeUnload patched'
}

$left = ([regex]::Matches($text, [regex]::Escape($CatRef) + '\.\w*' + [regex]::Escape($Suffix))).Count
$leftPco = ([regex]::Matches($text, '<' + $Source + '>' + [regex]::Escape($CatRef) + '\.\w*' + [regex]::Escape($Suffix) + '</')).Count
Write-Host ('Remaining CatRef.*Suffix: ' + $left)
Write-Host ('Remaining PCO Source tags: ' + $leftPco)
Write-Host ('New length: ' + $text.Length + ' delta=' + ($text.Length - $origLen))

if (-not (Test-Path -LiteralPath $backup)) {
	Write-Host 'Creating backup...'
	Copy-Item -LiteralPath $path -Destination $backup
} else {
	Write-Host 'Backup exists'
}

Write-Host 'Writing...'
$utf8NoBom = New-Object Text.UTF8Encoding $false
[IO.File]::WriteAllText($path, $text, $utf8NoBom)

$rep = New-Object System.Text.StringBuilder
[void]$rep.AppendLine('Suffix=' + $Suffix)
[void]$rep.AppendLine('Unique=' + $names.Count)
foreach ($n in $names) { [void]$rep.AppendLine('  ' + $n) }
[void]$rep.AppendLine('PCO_removed=' + $pcoCount)
[void]$rep.AppendLine('PVD_tab3=' + $pvdCount)
[void]$rep.AppendLine('PVD_tab2=' + $pvdCount2)
[void]$rep.AppendLine('ConvCode_removed=' + $convCount)
[void]$rep.AppendLine('Remaining_CatRef=' + $left)
[void]$rep.AppendLine('Remaining_PCO_Source=' + $leftPco)
[void]$rep.AppendLine('NewLen=' + $text.Length)
[IO.File]::WriteAllText($report, $rep.ToString(), [Text.Encoding]::UTF8)
Write-Host ('Report: ' + $report)
Write-Host 'DONE'
