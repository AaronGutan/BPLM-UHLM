# Scaffold UH CFE exchange plan from BP CFE (ASCII + names file)
$ErrorActionPreference = "Stop"
$Root = "e:\1C\AY\BPLM-UHLM-XML"
$SrcExt = Join-Path $Root "acclmcopy-cfe-consolidation"
$DstExt = Join-Path $Root "ICORUHM\uh-cfe-consolidation"
$UhCfg = Join-Path $Root "ICORUHM"
$TaskDir = Join-Path $Root ".tasks\task-cfe-consolidation-uh"
$CfeInit = Join-Path $Root ".cursor\skills\cfe-init\scripts\cfe-init.ps1"
$CfeBorrow = Join-Path $Root ".cursor\skills\cfe-borrow\scripts\cfe-borrow.ps1"
$Log = Join-Path $TaskDir "scaffold-log.txt"
$NamesFile = Join-Path $TaskDir "names.utf8.txt"

function Write-Utf8NoBom([string]$Path, [string]$Text) {
        $enc = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($Path, $Text, $enc)
}
function Log([string]$Msg) {
        $line = "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $Msg
        Add-Content -Path $Log -Value $line -Encoding UTF8
        Write-Host $line
}
function New-GuidStr { [guid]::NewGuid().ToString() }

$N = @{}
Get-Content $NamesFile -Encoding UTF8 | ForEach-Object {
        if ($_ -match "^(.*?)=(.*)$") { $N[$Matches[1]] = $Matches[2] }
}

"" | Set-Content $Log -Encoding UTF8
Log "START"

$cfgXml = Join-Path $DstExt "Configuration.xml"
if (-not (Test-Path $cfgXml)) {
        $dump = Join-Path $DstExt "ConfigDumpInfo.xml"
        if (Test-Path $dump) { Remove-Item $dump -Force }
        Log "cfe-init"
        & powershell.exe -NoProfile -File $CfeInit `
                -Name $N.ExtName -Synonym $N.ExtSynonym -NamePrefix $N.Prefix `
                -Purpose "AddOn" -Version "26_07_14_v1" -CompatibilityMode "Version8_3_21" `
                -ConfigPath $UhCfg -OutputDir $DstExt
        if ($LASTEXITCODE -ne 0) { throw "cfe-init failed" }
} else {
        Log "skip cfe-init"
}

$srcPlanDir = Join-Path $SrcExt ("ExchangePlans\" + $N.PlanName)
$dstPlanDir = Join-Path $DstExt ("ExchangePlans\" + $N.PlanName)
$dstPlanXml = Join-Path $DstExt ("ExchangePlans\" + $N.PlanName + ".xml")
$srcPlanXml = Join-Path $SrcExt ("ExchangePlans\" + $N.PlanName + ".xml")

if (Test-Path (Join-Path $DstExt "ExchangePlans")) {
        Remove-Item (Join-Path $DstExt "ExchangePlans") -Recurse -Force
}
New-Item -ItemType Directory -Force -Path (Join-Path $DstExt "ExchangePlans") | Out-Null
Copy-Item $srcPlanDir $dstPlanDir -Recurse -Force
Copy-Item $srcPlanXml $dstPlanXml -Force
Log "copied plan"

$uuidPattern = "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"
$planText = [System.IO.File]::ReadAllText($dstPlanXml, [System.Text.Encoding]::UTF8)
$map = @{}
$map["6e70f791-a5ba-4125-824f-b788750311d7"] = "6e70f791-a5ba-4125-824f-b788750311d7"
foreach ($m in [regex]::Matches($planText, $uuidPattern)) {
        $key = $m.Value.ToLower()
        if (-not $map.ContainsKey($key)) { $map[$key] = New-GuidStr }
}
$sb = New-Object System.Text.StringBuilder ($planText.Length + 256)
$last = 0
foreach ($m in [regex]::Matches($planText, $uuidPattern)) {
        [void]$sb.Append($planText.Substring($last, $m.Index - $last))
        [void]$sb.Append($map[$m.Value.ToLower()])
        $last = $m.Index + $m.Length
}
[void]$sb.Append($planText.Substring($last))
$newPlan = $sb.ToString()

# register templates
$formTag = "<Form>" + $N.FormName + "</Form>"
$insert = $formTag + "`r`n`t`t`t<Template>" + $N.TplRules + "</Template>`r`n`t`t`t<Template>" + $N.TplCorr + "</Template>`r`n`t`t`t<Template>" + $N.TplReg + "</Template>"
if ($newPlan -notmatch ("<Template>" + [regex]::Escape($N.TplRules) + "</Template>")) {
        $newPlan = $newPlan.Replace("`t`t`t" + $formTag, "`t`t`t" + $insert)
}
Write-Utf8NoBom $dstPlanXml $newPlan
Log "uuid rewrite + templates"

$formMeta = Join-Path $dstPlanDir ("Forms\" + $N.FormName + ".xml")
if (Test-Path $formMeta) {
        $ft = [System.IO.File]::ReadAllText($formMeta, [System.Text.Encoding]::UTF8)
        $ft2 = [regex]::Replace($ft, "uuid=`"$uuidPattern`"", { param($mm) "uuid=`"$(New-GuidStr)`"" })
        Write-Utf8NoBom $formMeta $ft2
}
$tplRoot = Join-Path $dstPlanDir "Templates"
if (Test-Path $tplRoot) {
        Get-ChildItem $tplRoot -Filter "*.xml" -File | ForEach-Object {
                $tt = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)
                $tt2 = [regex]::Replace($tt, "uuid=`"$uuidPattern`"", { param($mm) "uuid=`"$(New-GuidStr)`"" })
                Write-Utf8NoBom $_.FullName $tt2
        }
}

$contentPath = Join-Path $dstPlanDir "Ext\Content.xml"
$cText = [System.IO.File]::ReadAllText($contentPath, [System.Text.Encoding]::UTF8)
$cText = $cText.Replace("<AutoRecord>Allow</AutoRecord>", "<AutoRecord>Deny</AutoRecord>")
$cText = $cText.Replace("<AutoRecord>Enable</AutoRecord>", "<AutoRecord>Deny</AutoRecord>")
$regMeta = "InformationRegister." + $N.RegMap
if ($cText -notmatch [regex]::Escape($N.RegMap)) {
        $extra = "        <Item>`r`n                <Metadata>$regMeta</Metadata>`r`n                <AutoRecord>Deny</AutoRecord>`r`n        </Item>`r`n</ExchangePlanContent>"
        $cText = $cText.Replace("</ExchangePlanContent>", $extra)
}
Write-Utf8NoBom $contentPath $cText
Log "content Deny + mapping register"

foreach ($folder in @("CommonCommands", "CommandGroups")) {
        $src = Join-Path $SrcExt $folder
        $dst = Join-Path $DstExt $folder
        if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
        Copy-Item $src $dst -Recurse -Force
        Log ("copied " + $folder)
}

# Minimal ChildObjects update: ensure plan/commands/module listed; borrows add the rest
$cfgText = [System.IO.File]::ReadAllText($cfgXml, [System.Text.Encoding]::UTF8)
$cfgText = [regex]::Replace($cfgText, "<Version>.*?</Version>", "<Version>26_07_14_v1</Version>")

$must = @(
        "<CommonModule>$($N.OverrideModule)</CommonModule>",
        "<ExchangePlan>$($N.PlanName)</ExchangePlan>",
        "<Enum>$($N.EnumModes)</Enum>",
        "<CommonCommand>$($N.Cmd1)</CommonCommand>",
        "<CommonCommand>$($N.Cmd2)</CommonCommand>",
        "<CommonCommand>$($N.Cmd3)</CommonCommand>",
        "<CommonCommand>$($N.Cmd4)</CommonCommand>",
        "<CommonCommand>$($N.Cmd5)</CommonCommand>",
        "<CommonCommand>$($N.Cmd6)</CommonCommand>",
        "<CommonCommand>$($N.Cmd7)</CommonCommand>",
        "<CommandGroup>$($N.CmdGroup)</CommandGroup>",
        "<InformationRegister>$($N.RegMap)</InformationRegister>"
)

if ($cfgText -match "(?s)(<ChildObjects>)(.*?)(</ChildObjects>)") {
        $inner = $Matches[2]
        foreach ($tag in $must) {
                if ($inner -notmatch [regex]::Escape($tag)) {
                        $inner = "`r`n`t`t`t" + $tag + $inner
                }
        }
        $cfgText = $cfgText.Substring(0, $Matches.Index) + "<ChildObjects>" + $inner + "</ChildObjects>" + $cfgText.Substring($Matches.Index + $Matches.Length)
}
Write-Utf8NoBom $cfgXml $cfgText
Log "configuration childobjects patched"

function Borrow-Batch([string[]]$Objects, [string]$Label) {
        $batchSize = 12
        for ($i = 0; $i -lt $Objects.Count; $i += $batchSize) {
                $end = [Math]::Min($i + $batchSize - 1, $Objects.Count - 1)
                $batch = $Objects[$i..$end]
                $arg = ($batch -join " ;; ")
                $bn = [Math]::Floor($i / $batchSize) + 1
                Log ("$Label batch $bn count=$($batch.Count)")
                & powershell.exe -NoProfile -File $CfeBorrow -ExtensionPath $DstExt -ConfigPath $UhCfg -Object $arg
                if ($LASTEXITCODE -ne 0) { Log "WARN batch $bn exit=$LASTEXITCODE" }
        }
}

$contentItems = @(Get-Content (Join-Path $TaskDir "uh-present-content.txt") -Encoding UTF8 | Where-Object { $_.Trim() -ne "" })
$toBorrow = New-Object System.Collections.Generic.List[string]
$toBorrow.Add("CommonModule." + $N.OverrideModule)
$toBorrow.Add("Enum." + $N.EnumModes)
$toBorrow.Add("InformationRegister." + $N.RegMap)
foreach ($m in $contentItems) { if ($toBorrow -notcontains $m) { $toBorrow.Add($m) } }
Borrow-Batch $toBorrow.ToArray() "borrow"

# Modules (BSL written as UTF8 from here-strings with Cyrillic - file is BOM so PS parses OK)
$managerPath = Join-Path $dstPlanDir "Ext\ManagerModule.bsl"
Write-Utf8NoBom $managerPath ([System.IO.File]::ReadAllText((Join-Path $TaskDir "ManagerModule.bsl"), [System.Text.Encoding]::UTF8))
Write-Utf8NoBom (Join-Path $dstPlanDir "Ext\ObjectModule.bsl") ([System.IO.File]::ReadAllText((Join-Path $TaskDir "ObjectModule.bsl"), [System.Text.Encoding]::UTF8))
Write-Utf8NoBom (Join-Path $dstPlanDir ("Forms\" + $N.FormName + "\Ext\Form\Module.bsl")) ([System.IO.File]::ReadAllText((Join-Path $TaskDir "FormModule.bsl"), [System.Text.Encoding]::UTF8))
$overrideDir = Join-Path $DstExt ("CommonModules\" + $N.OverrideModule + "\Ext")
New-Item -ItemType Directory -Force -Path $overrideDir | Out-Null
Write-Utf8NoBom (Join-Path $overrideDir "Module.bsl") ([System.IO.File]::ReadAllText((Join-Path $TaskDir "OverrideModule.bsl"), [System.Text.Encoding]::UTF8))
Log "modules written"
Log "DONE"