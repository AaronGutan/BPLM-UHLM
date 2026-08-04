$ErrorActionPreference = 'Stop'
function U([int[]]$Codes) {
	$sb = New-Object System.Text.StringBuilder
	foreach ($c in $Codes) { [void]$sb.Append([char]$c) }
	return $sb.ToString()
}
$Suffix = U @(0x041F,0x0440,0x0438,0x0441,0x043E,0x0435,0x0434,0x0438,0x043D,0x0435,0x043D,0x043D,0x044B,0x0435,0x0424,0x0430,0x0439,0x043B,0x044B)
$CatRef = U @(0x0421,0x043F,0x0440,0x0430,0x0432,0x043E,0x0447,0x043D,0x0438,0x043A,0x0421,0x0441,0x044B,0x043B,0x043A,0x0430)
$SampleObj = U @(0x041E,0x0431,0x044A,0x0435,0x043A,0x0442,0x0412,0x044B,0x0431,0x043E,0x0440,0x043A,0x0438)
$ConvCode = U @(0x041A,0x043E,0x0434,0x041F,0x0440,0x0430,0x0432,0x0438,0x043B,0x0430,0x041A,0x043E,0x043D,0x0432,0x0435,0x0440,0x0442,0x0430,0x0446,0x0438,0x0438)
$Rule = U @(0x041F,0x0440,0x0430,0x0432,0x0438,0x043B,0x043E)
$Code = U @(0x041A,0x043E,0x0434)
$Disable = U @(0x041E,0x0442,0x043A,0x043B,0x044E,0x0447,0x0438,0x0442,0x044C)
$PVD = U @(0x041F,0x0440,0x0430,0x0432,0x0438,0x043B,0x0430,0x0412,0x044B,0x0433,0x0440,0x0443,0x0437,0x043A,0x0438,0x0414,0x0430,0x043D,0x043D,0x044B,0x0445)

$path = 'E:\1C\AY\BPLM-UHLM-XML\BPLM-UH33LM_remix.xml'
$bak = $path + '.bak-before-exclude-attached-files'
$bt = [IO.File]::ReadAllText($bak, [Text.Encoding]::UTF8)
$bi = $bt.IndexOf('<' + $PVD + '>')
$bp = $bt.Substring($bi)

Write-Host ('SampleObj+CatRef*Suffix in bak PVD: ' + ([regex]::Matches($bp, '<' + $SampleObj + '>' + [regex]::Escape($CatRef) + '\.\w*' + [regex]::Escape($Suffix))).Count)
Write-Host ('ConvCode*Suffix in bak PVD: ' + ([regex]::Matches($bp, '<' + $ConvCode + '>\w*' + [regex]::Escape($Suffix))).Count)
Write-Host ('Code*Suffix in bak PVD: ' + ([regex]::Matches($bp, '<' + $Code + '>\w*' + [regex]::Escape($Suffix) + '\s*<')).Count)

# dump one rule around first Code*Suffix
$m = [regex]::Match($bp, '(?s)\t{3}<' + $Rule + '[^>]*>\r?\n(?:(?!\t{3}</' + $Rule + '>).)*?<' + $Code + '>\w*' + [regex]::Escape($Suffix) + '\s*</' + $Code + '>.*?\t{3}</' + $Rule + '>')
Write-Host ('Found rule match: ' + $m.Success)
if ($m.Success) {
	$out = 'E:\1C\AY\BPLM-UHLM-XML\.tasks\_pvd-sample.txt'
	[IO.File]::WriteAllText($out, $m.Value, [Text.Encoding]::UTF8)
	Write-Host ('Wrote ' + $out + ' len=' + $m.Value.Length)
}

# Current file
$ct = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
$ci = $ct.IndexOf('<' + $PVD + '>')
$cp = $ct.Substring($ci)
Write-Host ('CURRENT Code*Suffix in PVD: ' + ([regex]::Matches($cp, '<' + $Code + '>\w*' + [regex]::Escape($Suffix) + '\s*<')).Count)
Write-Host ('CURRENT ConvCode*Suffix in PVD: ' + ([regex]::Matches($cp, '<' + $ConvCode + '>\w*' + [regex]::Escape($Suffix))).Count)
Write-Host ('CURRENT SampleObj+CatRef*Suffix: ' + ([regex]::Matches($cp, '<' + $SampleObj + '>' + [regex]::Escape($CatRef) + '\.\w*' + [regex]::Escape($Suffix))).Count)
