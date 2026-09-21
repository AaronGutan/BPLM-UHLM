# Pack both exchange-rule zips from remix.xml.
# Source (BP): full RegistrationRules from current remix.zip (or BPKORP zip).
# Receiver (UH): stub .tasks/RegistrationRules-UH-empty.xml
# ASCII-only source for Windows PowerShell 5.1.
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = "E:\1C\AY\BPLM-UHLM-XML"
. (Join-Path $root ".tasks\RulesXml-SafeWrite.ps1")

function ConvertFrom-UEscape([string]$s) {
	return [regex]::Replace($s, '\\u([0-9A-Fa-f]{4})', {
		param($m)
		return [string][char][Convert]::ToInt32($m.Groups[1].Value, 16)
	})
}

$utf8 = New-Object System.Text.UTF8Encoding $false
$remix = Join-Path $root "BPLM-UH33LM_remix.xml"
$stubUh = Join-Path $root ".tasks\RegistrationRules-UH-empty.xml"
$closeConv = ConvertFrom-UEscape('\u003c\u002f\u041f\u0440\u0430\u0432\u0438\u043b\u0430\u041e\u0431\u043c\u0435\u043d\u0430\u003e')
$closeReg = ConvertFrom-UEscape('\u003c\u002f\u041f\u0440\u0430\u0432\u0438\u043b\u0430\u0420\u0435\u0433\u0438\u0441\u0442\u0440\u0430\u0446\u0438\u0438\u003e')

if (-not (Test-Path -LiteralPath $remix)) { throw "remix.xml not found" }
if (-not (Test-Path -LiteralPath $stubUh)) { throw "UH RegistrationRules stub not found" }

Test-RulesXmlIntegrity -Path $remix | Out-Null
$rules = [IO.File]::ReadAllText($remix, $utf8)
if (-not $rules.TrimEnd().EndsWith($closeConv)) { throw "remix tail is not conversion root close" }

$elPro = ConvertFrom-UEscape('\u041f\u0440\u0430\u0432\u0438\u043b\u0430\u0420\u0435\u0433\u0438\u0441\u0442\u0440\u0430\u0446\u0438\u0438\u041e\u0431\u044a\u0435\u043a\u0442\u043e\u0432')
$stubText = [IO.File]::ReadAllText($stubUh, $utf8)
if (-not $stubText.TrimEnd().EndsWith($closeReg)) { throw "UH stub tail is not registration root close" }
if ($stubText -match ('<' + [regex]::Escape($elPro) + '>[^<]')) { throw "UH stub must have empty object registration rules" }

$srcZip = Join-Path $root "BPLM-UH33LM_remix.zip"
$uhZip = Join-Path $root "BPLM-UH33LM_remix-UH.zip"
$work = Join-Path $root ".tasks\_pack-rules-zips"
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
New-Item -ItemType Directory -Path $work | Out-Null

$tmpExtract = Join-Path $work "_extract"
New-Item -ItemType Directory -Path $tmpExtract | Out-Null
if (-not (Test-Path -LiteralPath $srcZip)) { throw "source zip not found: $srcZip" }
[IO.Compression.ZipFile]::ExtractToDirectory($srcZip, $tmpExtract)
$regBp = Join-Path $tmpExtract "RegistrationRules.xml"
if (-not (Test-Path $regBp)) { throw "RegistrationRules.xml missing in source zip" }
$regBpText = [IO.File]::ReadAllText($regBp, $utf8)
if (-not $regBpText.TrimEnd().EndsWith($closeReg)) { throw "BP RegistrationRules tail is not registration root close" }

$dirBp = Join-Path $work "bp"
$dirUh = Join-Path $work "uh"
New-Item -ItemType Directory -Path $dirBp | Out-Null
New-Item -ItemType Directory -Path $dirUh | Out-Null

[IO.File]::WriteAllText((Join-Path $dirBp "ExchangeRules.xml"), $rules, $utf8)
[IO.File]::WriteAllText((Join-Path $dirBp "CorrespondentExchangeRules.xml"), $rules, $utf8)
Copy-Item $regBp (Join-Path $dirBp "RegistrationRules.xml") -Force

[IO.File]::WriteAllText((Join-Path $dirUh "ExchangeRules.xml"), $rules, $utf8)
[IO.File]::WriteAllText((Join-Path $dirUh "CorrespondentExchangeRules.xml"), $rules, $utf8)
Copy-Item $stubUh (Join-Path $dirUh "RegistrationRules.xml") -Force

function Rebuild-Zip([string]$zipPath, [string]$fromDir) {
	$bak = $zipPath + ".bak-before-pack"
	if ((Test-Path -LiteralPath $zipPath) -and -not (Test-Path -LiteralPath $bak)) {
		Copy-Item -LiteralPath $zipPath -Destination $bak
	}
	if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
	[IO.Compression.ZipFile]::CreateFromDirectory($fromDir, $zipPath, [IO.Compression.CompressionLevel]::Optimal, $false)
	$z = [IO.Compression.ZipFile]::OpenRead($zipPath)
	try {
		$entries = @($z.Entries | ForEach-Object { $_.FullName + "=" + $_.Length })
		$names = @($z.Entries | ForEach-Object { $_.FullName })
		$count = $z.Entries.Count
	}
	finally { $z.Dispose() }
	Write-Host ("ZIP {0} size={1} count={2} entries={3}" -f (Split-Path $zipPath -Leaf), (Get-Item -LiteralPath $zipPath).Length, $count, ($entries -join ","))
	if ($count -ne 3) { throw "zip must have exactly 3 entries" }
	if ($names -match '\.bak|/') { throw "zip has bak or subfolder" }
	foreach ($need in @("ExchangeRules.xml","CorrespondentExchangeRules.xml","RegistrationRules.xml")) {
		if ($names -notcontains $need) { throw ("zip missing {0}" -f $need) }
	}
}

Rebuild-Zip $srcZip $dirBp
Rebuild-Zip $uhZip $dirUh

$bpk = Get-ChildItem -LiteralPath $root -Filter "*.zip" |
	Where-Object { $_.Name -like "*3.0.201.16*3.3.3.48.zip" -and $_.Name -notlike "*.bak*" -and $_.Name -notlike "*remix*" } |
	Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($bpk) { Rebuild-Zip $bpk.FullName $dirBp }

Remove-Item $work -Recurse -Force
Write-Host "DONE source=BPLM-UH33LM_remix.zip receiver=BPLM-UH33LM_remix-UH.zip"
