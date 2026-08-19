$ErrorActionPreference="Stop"
function U([string]$s){ return [regex]::Replace($s,"\\u([0-9A-Fa-f]{4})",{param($m)[string][char][Convert]::ToInt32($m.Groups[1].Value,16)}) }
$N=@{ PkoRoot=U("\u041f\u0440\u0430\u0432\u0438\u043b\u0430\u041a\u043e\u043d\u0432\u0435\u0440\u0442\u0430\u0446\u0438\u0438\u041e\u0431\u044a\u0435\u043a\u0442\u043e\u0432"); Rule=U("\u041f\u0440\u0430\u0432\u0438\u043b\u043e"); Code=U("\u041a\u043e\u0434"); ConvRef=U("\u041a\u043e\u0434\u041f\u0440\u0430\u0432\u0438\u043b\u0430\u041a\u043e\u043d\u0432\u0435\u0440\u0442\u0430\u0446\u0438\u0438"); Prop=U("\u0421\u0432\u043e\u0439\u0441\u0442\u0432\u043e"); Name=U("\u041d\u0430\u0438\u043c\u0435\u043d\u043e\u0432\u0430\u043d\u0438\u0435") }
$doc=New-Object System.Xml.XmlDocument; $doc.Load("E:\1C\AY\BPLM-UHLM-XML\BPLM-UH33LM_remix.xml")
$root=$doc.DocumentElement.SelectSingleNode($N.PkoRoot)
$codes=@{}
foreach($r in $root.SelectNodes(".//"+$N.Rule)){
  $c=$r.SelectSingleNode($N.Code); if($null -eq $c){continue}
  $code=([string]$c.InnerText).Trim(); if($code -ne ""){ $codes[$code]=$true }
}
$targets=@(
"КэшВизуализацииДокументовЭДОПрисоединенныеФай",
"ИсторияПроверкиИКорректировкиДанныхПрисоедине",
"ОтказВВозмещенииВыплатРодителямДетейИнвалидов",
"ДополнительныеСведенияДляОплатыОтпускаСФРПрис",
"СведенияДляОплатыОтпускаСФРПрисоединенныеФайл",
"ДокументацияПоКонтролируемымСделкамПрисоедине",
"ОтветСтрахователяНаОбращениеСФРПрисоединенные"
)
$sb=New-Object Text.StringBuilder
[void]$sb.AppendLine("PKO hashtable size=$($codes.Count)")
foreach($t in $targets){
  $exact=$codes.ContainsKey($t)
  $pref=@($codes.Keys | Where-Object { $_.StartsWith($t.Substring(0,[Math]::Min(30,$t.Length))) } | Select-Object -First 8)
  [void]$sb.AppendLine("TARGET len=$($t.Length) exists=$exact name=$t")
  foreach($p in $pref){ [void]$sb.AppendLine("  candidate len=$($p.Length) $p") }
}
# find codes ending / containing Priosoed
$att=@($codes.Keys | Where-Object { $_ -match "Присоединенн" } | Sort-Object)
[void]$sb.AppendLine("Attached-like PKO count=$($att.Count)")
foreach($a in ($att|Select-Object -First 40)){ [void]$sb.AppendLine("  ATT $a") }
[IO.File]::WriteAllText("E:\1C\AY\BPLM-UHLM-XML\.tasks\_rules-broken-detail.txt", $sb.ToString(), [Text.UTF8Encoding]::new($false))
Write-Host "done"