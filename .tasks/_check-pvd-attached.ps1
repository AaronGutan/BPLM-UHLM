# Find remaining unload rules for attached-file catalogs
$ErrorActionPreference = 'Stop'
function U([int[]]$Codes) {
	$sb = New-Object System.Text.StringBuilder
	foreach ($c in $Codes) { [void]$sb.Append([char]$c) }
	return $sb.ToString()
}
$Suffix = U @(0x041F,0x0440,0x0438,0x0441,0x043E,0x0435,0x0434,0x0438,0x043D,0x0435,0x043D,0x043D,0x044B,0x0435,0x0424,0x0430,0x0439,0x043B,0x044B)
$CatalogDot = U @(0x0421,0x043F,0x0440,0x0430,0x0432,0x043E,0x0447,0x043D,0x0438,0x043A,0x002E)
$SampleObj = U @(0x041E,0x0431,0x044A,0x0435,0x043A,0x0442,0x0412,0x044B,0x0431,0x043E,0x0440,0x043A,0x0438)
$ConvCode = U @(0x041A,0x043E,0x0434,0x041F,0x0440,0x0430,0x0432,0x0438,0x043B,0x0430,0x041A,0x043E,0x043D,0x0432,0x0435,0x0440,0x0442,0x0430,0x0446,0x0438,0x0438)
$PVD = U @(0x041F,0x0440,0x0430,0x0432,0x0438,0x043B,0x0430,0x0412,0x044B,0x0433,0x0440,0x0443,0x0437,0x043A,0x0438,0x0414,0x0430,0x043D,0x043D,0x044B,0x0445)

$path = 'E:\1C\AY\BPLM-UHLM-XML\BPLM-UH33LM_remix.xml'
$bak = $path + '.bak-before-exclude-attached-files'
$text = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)

$idx = $text.IndexOf('<' + $PVD + '>')
Write-Host ('PVD start index: ' + $idx)
$pvdPart = if ($idx -ge 0) { $text.Substring($idx) } else { '' }

$c1 = ([regex]::Matches($pvdPart, [regex]::Escape($CatalogDot) + '\w*' + [regex]::Escape($Suffix))).Count
$c2 = ([regex]::Matches($pvdPart, '<' + $ConvCode + '>\w*' + [regex]::Escape($Suffix))).Count
$c3 = ([regex]::Matches($pvdPart, [regex]::Escape($Suffix))).Count
Write-Host ('In PVD section: CatalogDot*Suffix=' + $c1 + ' ConvCode*Suffix=' + $c2 + ' any Suffix=' + $c3)

# Sample of Suffix lines in PVD
$m = [regex]::Matches($pvdPart, '.{0,80}' + [regex]::Escape($Suffix) + '.{0,40}')
Write-Host ('Sample hits in PVD: ' + $m.Count)
for ($i = 0; $i -lt [Math]::Min(5, $m.Count); $i++) {
	Write-Host ('---')
	Write-Host ($m[$i].Value -replace '\s+', ' ')
}

# In backup PVD
if (Test-Path $bak) {
	$bt = [IO.File]::ReadAllText($bak, [Text.Encoding]::UTF8)
	$bi = $bt.IndexOf('<' + $PVD + '>')
	$bp = $bt.Substring($bi)
	$bc1 = ([regex]::Matches($bp, [regex]::Escape($CatalogDot) + '\w*' + [regex]::Escape($Suffix))).Count
	Write-Host ('Backup PVD CatalogDot*Suffix: ' + $bc1)
}
