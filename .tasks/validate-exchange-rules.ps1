# Validates KD 2.x exchange rules XML (static checks). ASCII-only source for PS 5.1.
param(
	[Parameter(Mandatory = $true)]
	[string]$RulesFile,
	[string]$OutJson = "E:\1C\AY\BPLM-UHLM-XML\.tasks\_rules-validation.json",
	[string]$OutText = "E:\1C\AY\BPLM-UHLM-XML\.tasks\_rules-validation.txt"
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path -LiteralPath $RulesFile)) { throw "File not found: $RulesFile" }

# Cyrillic element/attr names via \u escapes (no literal Cyrillic in file)
function Get-Text($node, $child) {
	if ($null -eq $node) { return "" }
	$c = $node.SelectSingleNode([string]$child)
	if ($null -eq $c) { return "" }
	return ([string]$c.InnerText).Trim()
}

function U([string]$s) {
	return [regex]::Replace($s, '\\u([0-9A-Fa-f]{4})', {
		param($m)
		return [string][char][Convert]::ToInt32($m.Groups[1].Value, 16)
	})
}

$N = @{
	PkoRoot   = U('\u041f\u0440\u0430\u0432\u0438\u043b\u0430\u041a\u043e\u043d\u0432\u0435\u0440\u0442\u0430\u0446\u0438\u0438\u041e\u0431\u044a\u0435\u043a\u0442\u043e\u0432')
	Rule      = U('\u041f\u0440\u0430\u0432\u0438\u043b\u043e')
	Group     = U('\u0413\u0440\u0443\u043f\u043f\u0430')
	Code      = U('\u041a\u043e\u0434')
	Name      = U('\u041d\u0430\u0438\u043c\u0435\u043d\u043e\u0432\u0430\u043d\u0438\u0435')
	Order     = U('\u041f\u043e\u0440\u044f\u0434\u043e\u043a')
	Source    = U('\u0418\u0441\u0442\u043e\u0447\u043d\u0438\u043a')
	Dest      = U('\u041f\u0440\u0438\u0435\u043c\u043d\u0438\u043a')
	Props     = U('\u0421\u0432\u043e\u0439\u0441\u0442\u0432\u0430')
	Prop      = U('\u0421\u0432\u043e\u0439\u0441\u0442\u0432\u043e')
	Values    = U('\u0417\u043d\u0430\u0447\u0435\u043d\u0438\u044f')
	Value     = U('\u0417\u043d\u0430\u0447\u0435\u043d\u0438\u0435')
	ConvRef   = U('\u041a\u043e\u0434\u041f\u0440\u0430\u0432\u0438\u043b\u0430\u041a\u043e\u043d\u0432\u0435\u0440\u0442\u0430\u0446\u0438\u0438')
	Disable   = U('\u041e\u0442\u043a\u043b\u044e\u0447\u0438\u0442\u044c')
	AttrName  = U('\u0418\u043c\u044f')
	EnumPrefix = U('\u041f\u0435\u0440\u0435\u0447\u0438\u0441\u043b\u0435\u043d\u0438\u0435\u0421\u0441\u044b\u043b\u043a\u0430.')
}

Write-Host "Loading XML..."
$doc = New-Object System.Xml.XmlDocument
$doc.PreserveWhitespace = $false
$doc.Load($RulesFile)

$pkoRoot = $doc.DocumentElement.SelectSingleNode($N.PkoRoot)
if ($null -eq $pkoRoot) { throw "PKO root element not found" }

$ruleNodes = $pkoRoot.SelectNodes(".//" + $N.Rule)
Write-Host ("Rule nodes: {0}" -f $ruleNodes.Count)

$pko = @{}
$dupCodes = New-Object System.Collections.Generic.List[object]
$refs = New-Object System.Collections.Generic.List[object]
$emptyType = New-Object System.Collections.Generic.List[object]
$enumPkz = New-Object System.Collections.Generic.List[object]
$pkzEmpty = New-Object System.Collections.Generic.List[object]
$pkzRenamed = New-Object System.Collections.Generic.List[object]
$enumTypeMismatch = New-Object System.Collections.Generic.List[object]
$propRefCount = 0
$valueMapCount = 0
$enumPkoCount = 0

$ruleIndex = 0
foreach ($rule in $ruleNodes) {
	$ruleIndex++
	try {
	# Skip non-PKO rules: a PKO rule has Source and/or Dest child elements directly
	$srcNode = $rule.SelectSingleNode($N.Source)
	$dstNode = $rule.SelectSingleNode($N.Dest)
	# Nested rule markup also has Code; real PKO always has Source OR Dest (enum/object)
	# Group wrappers are "Group" not "Rule". But some rules may have only values.
	$code = Get-Text $rule $N.Code
	$name = Get-Text $rule $N.Name
	$src = if ($srcNode) { ([string]$srcNode.InnerText).Trim() } else { "" }
	$dst = if ($dstNode) { ([string]$dstNode.InnerText).Trim() } else { "" }

	# Ignore nested bogus: property blocks don't use Rule. All Rule under PKO root that have Code
	# and (Source or Dest or Values) are PKO.
	$valuesNode = $rule.SelectSingleNode($N.Values)
	$propsNode = $rule.SelectSingleNode($N.Props)
	if ([string]::IsNullOrWhiteSpace($src) -and [string]::IsNullOrWhiteSpace($dst) -and $null -eq $valuesNode -and $null -eq $propsNode) {
		continue
	}
	# If this Rule contains child Rule elements and no Source - grouping mistaken as Rule
	$childRules = $rule.SelectNodes($N.Rule)
	$childRuleCount = 0
	if ($null -ne $childRules) { $childRuleCount = $childRules.Count }
	if ($childRuleCount -gt 0 -and [string]::IsNullOrWhiteSpace($src) -and [string]::IsNullOrWhiteSpace($dst)) {
		continue
	}

	if ([string]::IsNullOrWhiteSpace($code)) { continue }

	$isEnum = $false
	if (-not [string]::IsNullOrWhiteSpace($src)) {
		$isEnum = $src.StartsWith($N.EnumPrefix, [System.StringComparison]::Ordinal)
	}
	if ($isEnum) { $enumPkoCount++ }

	if ($pko.ContainsKey($code)) {
		$dupCodes.Add([pscustomobject]@{ Code = $code; First = [string]$pko[$code].Name; Second = $name }) | Out-Null
	} else {
		$pko[$code] = [pscustomobject]@{ Code = $code; Name = $name; Source = $src; Dest = $dst; IsEnum = $isEnum }
	}

	$srcEmpty = [string]::IsNullOrWhiteSpace($src)
	$dstEmpty = [string]::IsNullOrWhiteSpace($dst)
	if (($srcEmpty -and -not $dstEmpty) -or ((-not $srcEmpty) -and $dstEmpty)) {
		$emptyType.Add([pscustomobject]@{ Code = $code; Name = $name; Source = $src; Dest = $dst }) | Out-Null
	}
	if ($isEnum -and (-not $dstEmpty) -and ($src -ne $dst)) {
		$enumTypeMismatch.Add([pscustomobject]@{ Code = $code; Name = $name; Source = $src; Dest = $dst }) | Out-Null
	}

	if ($null -ne $propsNode) {
		$propNodes = $propsNode.SelectNodes(".//" + $N.Prop)
		if ($null -ne $propNodes) {
			foreach ($prop in $propNodes) {
				$refNode = $prop.SelectSingleNode($N.ConvRef)
				if ($null -eq $refNode) { continue }
				$ref = ([string]$refNode.InnerText).Trim()
				if ([string]::IsNullOrWhiteSpace($ref)) { continue }
				$propRefCount++
				$disabled = $false
				$attr = $prop.Attributes.GetNamedItem($N.Disable)
				if ($null -ne $attr -and $attr.Value -eq "true") { $disabled = $true }
				$propName = Get-Text $prop $N.Name
				$refs.Add([pscustomobject]@{
						FromPko = $code
						FromPkoName = $name
						Prop = $propName
						Ref = $ref
						Disabled = $disabled
					}) | Out-Null
			}
		}
	}

	if ($isEnum -and $null -ne $valuesNode) {
		$valNodes = $valuesNode.SelectNodes($N.Value)
		if ($null -ne $valNodes) {
			foreach ($val in $valNodes) {
				$valueMapCount++
				$vs = Get-Text $val $N.Source
				$vd = Get-Text $val $N.Dest
				$row = [pscustomobject]@{
					Pko = $code
					PkoName = $name
					SourceType = $src
					DestType = $dst
					SourceValue = $vs
					DestValue = $vd
				}
				$enumPkz.Add($row) | Out-Null
				if ([string]::IsNullOrWhiteSpace($vs) -or [string]::IsNullOrWhiteSpace($vd)) {
					$pkzEmpty.Add($row) | Out-Null
				} elseif ($vs -ne $vd) {
					$pkzRenamed.Add($row) | Out-Null
				}
			}
		}
	}
	} catch {
		$msg = "FAIL ruleIndex=$ruleIndex code=$code err=$($_.Exception.GetType().FullName) $($_.Exception.Message)"
		Write-Host $msg
		throw $msg
	}
}

Write-Host ("Loop done. PKO={0} refs={1} enumPkz={2}" -f $pko.Count, $refs.Count, $enumPkz.Count)

$broken = New-Object System.Collections.Generic.List[object]
foreach ($r in $refs) {
	if (-not $pko.ContainsKey([string]$r.Ref)) { $broken.Add($r) | Out-Null }
}

Write-Host ("Broken refs: {0}" -f $broken.Count)

function S($x) { return [string]$x }

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("=== Exchange rules validation ===")
[void]$sb.AppendLine("File: $RulesFile")
[void]$sb.AppendLine("PKO=$($pko.Count); ConvRefs=$propRefCount; EnumPKZ=$($enumPkz.Count); RenamedEnumPKZ=$($pkzRenamed.Count)")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("--- ERRORS ---")
[void]$sb.AppendLine("Duplicate PKO codes: $($dupCodes.Count)")
foreach ($d in $dupCodes) { [void]$sb.AppendLine("  DUP $(S $d.Code) | $(S $d.First) / $(S $d.Second)") }
[void]$sb.AppendLine("Broken KodPravilaKonvertacii: $($broken.Count)")
$bi = 0
foreach ($b in $broken) {
	$bi++
	if ($bi -gt 300) { break }
	$flag = ""
	if ($b.Disabled) { $flag = " [disabled]" }
	[void]$sb.AppendLine("  REF $(S $b.FromPko) :: $(S $b.Prop) -> [$(S $b.Ref)]$flag")
}
if ($broken.Count -gt 300) { [void]$sb.AppendLine("  ... +$($broken.Count - 300) more") }
[void]$sb.AppendLine("PKO with only one side type: $($emptyType.Count)")
foreach ($e in $emptyType) { [void]$sb.AppendLine("  EMPTY $(S $e.Code) | $(S $e.Name) | src=$(S $e.Source) dst=$(S $e.Dest)") }
[void]$sb.AppendLine("Enum PKZ empty side: $($pkzEmpty.Count)")
foreach ($e in $pkzEmpty) { [void]$sb.AppendLine("  PKZ-EMPTY $(S $e.Pko) $(S $e.SourceValue)->$(S $e.DestValue)") }
[void]$sb.AppendLine("")
[void]$sb.AppendLine("--- WARNINGS ---")
[void]$sb.AppendLine("Enum type src!=dst: $($enumTypeMismatch.Count)")
foreach ($e in $enumTypeMismatch) { [void]$sb.AppendLine("  ENUM-TYPE $(S $e.Code) $(S $e.Source) => $(S $e.Dest)") }
[void]$sb.AppendLine("Renamed enum values (UH init risk): $($pkzRenamed.Count)")
$sortedRename = $pkzRenamed | Sort-Object { $_.Pko }, { $_.SourceValue }
foreach ($e in $sortedRename) {
	[void]$sb.AppendLine("  RENAME $(S $e.Pko) | $(S $e.SourceType) | $(S $e.SourceValue) -> $(S $e.DestValue)")
}

$summary = [ordered]@{
	File = $RulesFile
	CheckedAt = (Get-Date).ToString("s")
	Stats = [ordered]@{
		PkoCount = $pko.Count
		EnumPko = $enumPkoCount
		PropertyConvRefs = $propRefCount
		EnumValueMaps = $enumPkz.Count
		RenamedEnumValues = $pkzRenamed.Count
		DuplicatePkoCodes = $dupCodes.Count
		BrokenConversionRefs = $broken.Count
		PkoOneSideTypeEmpty = $emptyType.Count
		EmptyEnumValueSides = $pkzEmpty.Count
		EnumSourceDestTypeMismatch = $enumTypeMismatch.Count
	}
	BrokenRefsSample = @($broken | Select-Object -First 50 | ForEach-Object { "$($_.FromPko) -> $($_.Ref)" })
	RenamedSample = @($sortedRename | Select-Object -First 50 | ForEach-Object { "$($_.Pko): $($_.SourceValue) -> $($_.DestValue)" })
}

$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($OutText, $sb.ToString(), $utf8)
[System.IO.File]::WriteAllText($OutJson, ($summary | ConvertTo-Json -Depth 5), $utf8)

$csvPath = $OutText -replace '\.txt$', '-renamed-enum.csv'
if ($csvPath -eq $OutText) { $csvPath = "$OutText-renamed-enum.csv" }
$sw = New-Object System.IO.StreamWriter($csvPath, $false, $utf8)
$sw.WriteLine("Pko;SourceType;SourceValue;DestValue")
foreach ($e in $sortedRename) {
	$sw.WriteLine((S $e.Pko) + ";" + (S $e.SourceType) + ";" + (S $e.SourceValue) + ";" + (S $e.DestValue))
}
$sw.Close()

Write-Host ("OK PKO={0} broken={1} dup={2} renamedEnum={3} emptySide={4}" -f $pko.Count, $broken.Count, $dupCodes.Count, $pkzRenamed.Count, $emptyType.Count)
Write-Host "TXT: $OutText"
Write-Host "JSON: $OutJson"
Write-Host "CSV: $csvPath"

if ($dupCodes.Count -gt 0 -or $broken.Count -gt 0 -or $emptyType.Count -gt 0 -or $pkzEmpty.Count -gt 0) { exit 2 }
exit 0
