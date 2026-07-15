$ErrorActionPreference = "Stop"
$manifest = Get-Content "e:\1C\AY\BPLM-UHLM-XML\.tasks\task-cfe-consolidation\rules-exchange-manifest.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$ext = "e:\1C\AY\BPLM-UHLM-XML\acclmcopy-cfe-consolidation"
$cfg = "e:\1C\AY\BPLM-UHLM-XML\acclmcopy"
$borrow = "e:\1C\AY\BPLM-UHLM-XML\.cursor\skills\cfe-borrow\scripts\cfe-borrow.ps1"
$log = "e:\1C\AY\BPLM-UHLM-XML\.tasks\task-cfe-consolidation\borrow-log.txt"

$all = @($manifest.objects | ForEach-Object { $_.metadata })
$already = @()
$catDir = Join-Path $ext "Catalogs"
$docDir = Join-Path $ext "Documents"
if (Test-Path $catDir) {
  Get-ChildItem $catDir -Filter "*.xml" -File | ForEach-Object { $already += ("Catalog." + $_.BaseName) }
}
if (Test-Path $docDir) {
  Get-ChildItem $docDir -Filter "*.xml" -File | ForEach-Object { $already += ("Document." + $_.BaseName) }
}
$todo = @($all | Where-Object { $already -notcontains $_ })
"Total=$($all.Count) already=$($already.Count) todo=$($todo.Count)" | Tee-Object -FilePath $log

$batchSize = 15
$ok = 0
$fail = 0
for ($i = 0; $i -lt $todo.Count; $i += $batchSize) {
  $end = [Math]::Min($i + $batchSize - 1, $todo.Count - 1)
  $batch = $todo[$i..$end]
  $objectArg = ($batch -join " ;; ")
  $batchNum = [Math]::Floor($i / $batchSize) + 1
  $msg = "=== Batch $batchNum ($($batch.Count)) ==="
  $msg | Tee-Object -FilePath $log -Append
  & powershell.exe -NoProfile -File $borrow -ExtensionPath $ext -ConfigPath $cfg -Object $objectArg 2>&1 | Tee-Object -FilePath $log -Append
  if ($LASTEXITCODE -ne 0) {
    $fail += $batch.Count
    "FAIL batch $batchNum exit=$LASTEXITCODE" | Tee-Object -FilePath $log -Append
  } else {
    $ok += $batch.Count
    "OK batch $batchNum" | Tee-Object -FilePath $log -Append
  }
}
"DONE ok=$ok fail=$fail" | Tee-Object -FilePath $log -Append