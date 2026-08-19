$ErrorActionPreference = "Stop"
function U([string]$s) {
  return [regex]::Replace($s, "\\u([0-9A-Fa-f]{4})", { param($m) [string][char][Convert]::ToInt32($m.Groups[1].Value, 16) })
}
$N = @{
  PkoRoot = U("\u041f\u0440\u0430\u0432\u0438\u043b\u0430\u041a\u043e\u043d\u0432\u0435\u0440\u0442\u0430\u0446\u0438\u0438\u041e\u0431\u044a\u0435\u043a\u0442\u043e\u0432")
  Rule = U("\u041f\u0440\u0430\u0432\u0438\u043b\u043e")
  Code = U("\u041a\u043e\u0434")
  ConvRef = U("\u041a\u043e\u0434\u041f\u0440\u0430\u0432\u0438\u043b\u0430\u041a\u043e\u043d\u0432\u0435\u0440\u0442\u0430\u0446\u0438\u0438")
  Prop = U("\u0421\u0432\u043e\u0439\u0441\u0442\u0432\u043e")
  Name = U("\u041d\u0430\u0438\u043c\u0435\u043d\u043e\u0432\u0430\u043d\u0438\u0435")
}
$path = "E:\1C\AY\BPLM-UHLM-XML\BPLM-UH33LM_remix.xml"
$doc = New-Object System.Xml.XmlDocument
$doc.PreserveWhitespace = $true
$doc.Load($path)
$root = $doc.DocumentElement.SelectSingleNode($N.PkoRoot)
$codes = @{}
foreach ($r in $root.SelectNodes(".//" + $N.Rule)) {
  $c = $r.SelectSingleNode($N.Code)
  if ($null -eq $c) { continue }
  $code = ([string]$c.InnerText).Trim()
  if ($code -ne "") { $codes[$code] = $true }
}
$removed = New-Object System.Collections.Generic.List[string]
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
      [void]$removed.Add("$from :: $propName -> [$ref]")
      [void]$prop.RemoveChild($refNode)
    }
  }
}
$settings = New-Object System.Xml.XmlWriterSettings
$settings.Encoding = New-Object System.Text.UTF8Encoding $false
$settings.Indent = $true
$settings.IndentChars = "`t"
$settings.OmitXmlDeclaration = $true
$settings.NewLineChars = "`n"
$settings.NewLineHandling = [System.Xml.NewLineHandling]::Replace
# Preserve original style roughly - XmlDocument Save may reformat. Use Save with UTF8 no BOM.
$utf8 = New-Object System.Text.UTF8Encoding $false
$sw = New-Object System.IO.StreamWriter($path, $false, $utf8)
$doc.Save($sw)
$sw.Close()
$log = "E:\1C\AY\BPLM-UHLM-XML\.tasks\_rules-fixed-broken-refs.txt"
[IO.File]::WriteAllLines($log, $removed, $utf8)
Write-Host "Removed $($removed.Count) broken refs"