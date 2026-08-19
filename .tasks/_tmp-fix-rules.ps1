$ErrorActionPreference = "Stop"
function U([string]$s) {
  return [regex]::Replace($s, "\\u([0-9A-Fa-f]{4})", { param($m) [string][char][Convert]::ToInt32($m.Groups[1].Value, 16) })
}
$N = @{
  PkoRoot = U("\u041f\u0440\u0430\u0432\u0438\u043b\u0430\u041a\u043e\u043d\u0432\u0435\u0440\u0442\u0430\u0446\u0438\u0438\u041e\u0431\u044a\u0435\u043a\u0442\u043e\u0432")
  Rule = U("\u041f\u0440\u0430\u0432\u0438\u043b\u043e")
  Code = U("\u041a\u043e\u0434")
  Name = U("\u041d\u0430\u0438\u043c\u0435\u043d\u043e\u0432\u0430\u043d\u0438\u0435")
  Source = U("\u0418\u0441\u0442\u043e\u0447\u043d\u0438\u043a")
  Dest = U("\u041f\u0440\u0438\u0435\u043c\u043d\u0438\u043a")
  Values = U("\u0417\u043d\u0430\u0447\u0435\u043d\u0438\u044f")
  Value = U("\u0417\u043d\u0430\u0447\u0435\u043d\u0438\u0435")
  ConvRef = U("\u041a\u043e\u0434\u041f\u0440\u0430\u0432\u0438\u043b\u0430\u041a\u043e\u043d\u0432\u0435\u0440\u0442\u0430\u0446\u0438\u0438")
  Prop = U("\u0421\u0432\u043e\u0439\u0441\u0442\u0432\u043e")
}
$path = "E:\1C\AY\BPLM-UHLM-XML\BPLM-UH33LM_remix.xml"
Write-Host "Loading..."
$doc = New-Object System.Xml.XmlDocument
$doc.PreserveWhitespace = $true
$doc.Load($path)
$root = $doc.DocumentElement.SelectSingleNode($N.PkoRoot)

# 1) Remove PKZ VypłatyIPosobiya
$removedPkz = 0
foreach ($rule in $root.SelectNodes(".//" + $N.Rule)) {
  $codeNode = $rule.SelectSingleNode($N.Code)
  if ($null -eq $codeNode) { continue }
  if (([string]$codeNode.InnerText).Trim() -ne "СтраницыЖурналаОтчетность") { continue }
  $values = $rule.SelectSingleNode($N.Values)
  if ($null -eq $values) { continue }
  $toRemove = @()
  foreach ($val in $values.SelectNodes($N.Value)) {
    $src = $val.SelectSingleNode($N.Source)
    if ($null -ne $src -and ([string]$src.InnerText).Trim() -eq "ВыплатыИПособия") {
      $toRemove += $val
    }
  }
  foreach ($val in $toRemove) {
    [void]$values.RemoveChild($val)
    $removedPkz++
  }
}
Write-Host "Removed PKZ: $removedPkz"

# 2) Remove broken conversion refs
$codes = @{}
foreach ($r in $root.SelectNodes(".//" + $N.Rule)) {
  $c = $r.SelectSingleNode($N.Code)
  if ($null -eq $c) { continue }
  $code = ([string]$c.InnerText).Trim()
  if ($code -ne "") { $codes[$code] = $true }
}
$removedRefs = New-Object System.Collections.Generic.List[string]
foreach ($r in $root.SelectNodes(".//" + $N.Rule)) {
  $fromNode = $r.SelectSingleNode($N.Code)
  $from = if ($fromNode) { ([string]$fromNode.InnerText).Trim() } else { "?" }
  foreach ($prop in $r.SelectNodes(".//" + $N.Prop)) {
    $refNode = $prop.SelectSingleNode($N.ConvRef)
    if ($null -eq $refNode) { continue }
    $ref = ([string]$refNode.InnerText).Trim()
    if ($ref -eq "") { continue }
    if (-not $codes.ContainsKey($ref)) {
      $propNameNode = $prop.SelectSingleNode($N.Name)
      $propName = if ($propNameNode) { ([string]$propNameNode.InnerText).Trim() } else { "?" }
      [void]$removedRefs.Add("$from :: $propName -> [$ref]")
      [void]$prop.RemoveChild($refNode)
    }
  }
}
Write-Host "Removed broken refs: $($removedRefs.Count)"

Write-Host "Saving..."
$utf8 = New-Object System.Text.UTF8Encoding $false
$tmp = $path + ".tmp"
$sw = New-Object System.IO.StreamWriter($tmp, $false, $utf8)
$doc.Save($sw)
$sw.Close()

# validate temp
$check = New-Object System.Xml.XmlDocument
$check.Load($tmp)
Write-Host "Temp XML OK, size=$((Get-Item $tmp).Length)"
Move-Item -LiteralPath $tmp -Destination $path -Force

$log = "E:\1C\AY\BPLM-UHLM-XML\.tasks\_rules-fixed-broken-refs.txt"
$lines = @("Removed PKZ VypłatyIPosobiya: $removedPkz", "Removed broken refs: $($removedRefs.Count)") + @($removedRefs)
[IO.File]::WriteAllLines($log, $lines, $utf8)
Write-Host "Done log=$log"