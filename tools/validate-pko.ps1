$ErrorActionPreference='Stop'
$x = New-Object System.Xml.XmlDocument
$x.Load('E:\1C\AY\BPLM-UHLM-XML\BPLM-UHLM.xml')
$ns = New-Object System.Xml.XmlNamespaceManager($x.NameTable)
$pko = $x.SelectSingleNode('//ПравилаКонвертацииОбъектов',$ns)
$defined = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($r in $pko.SelectNodes('.//Правило',$ns)) {
  $c = $r.SelectSingleNode('Код',$ns)
  if ($c) { [void]$defined.Add($c.InnerText.Trim()) }
}
$orphan = @()
foreach ($ref in $x.SelectNodes('//КодПравилаКонвертации',$ns)) {
  $code = $ref.InnerText.Trim()
  if ($code -and -not $defined.Contains($code)) { $orphan += $code }
}
$orphan = $orphan | Select-Object -Unique
Write-Output "Orphan references: $($orphan.Count)"
$orphan | Select-Object -First 15