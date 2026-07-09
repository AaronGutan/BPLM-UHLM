# Сборка EPF: сборка внешней обработки из XML-исходников
param(
    [string]$SourceDir,
    [string]$ProcessorName,
    [string]$OutputFile,
    [string]$DatabaseId = "uh-lm",
    [string]$UserName,
    [string]$CopyToDir = "S:\1C Dev\LM\BPLM-UHLM"
)

$ErrorActionPreference = "Stop"

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
$projectFile = Join-Path $workspaceRoot ".v8-project.json"
$buildScript = Join-Path $workspaceRoot ".cursor/skills/epf-build/scripts/epf-build.ps1"

if (-not $SourceDir) {
    $SourceDir = Join-Path $workspaceRoot "ID_org"
}

if (-not (Test-Path $SourceDir)) {
    Write-Host "Ошибка: каталог исходников не найден: $SourceDir" -ForegroundColor Red
    exit 1
}

if (-not $ProcessorName) {
    $rootXml = Get-ChildItem -Path $SourceDir -Filter "*.xml" -File |
        Where-Object { $_.Name -notmatch "\\Forms\\|\\Templates\\" } |
        Sort-Object Name |
        Select-Object -First 1

    if (-not $rootXml) {
        Write-Host "Ошибка: корневой XML-файл обработки не найден в $SourceDir" -ForegroundColor Red
        exit 1
    }

    $ProcessorName = [System.IO.Path]::GetFileNameWithoutExtension($rootXml.Name)
}

$sourceFile = Join-Path $SourceDir "$ProcessorName.xml"
if (-not (Test-Path $sourceFile)) {
    Write-Host "Ошибка: исходный файл не найден: $sourceFile" -ForegroundColor Red
    exit 1
}

if (-not $OutputFile) {
    $buildDir = Join-Path $workspaceRoot "build"
    $OutputFile = Join-Path $buildDir "$ProcessorName.epf"
}

if (-not (Test-Path $projectFile)) {
    Write-Host "Ошибка: .v8-project.json не найден в корне проекта" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $buildScript)) {
    Write-Host "Ошибка: скрипт сборки не найден: $buildScript" -ForegroundColor Red
    exit 1
}

$project = Get-Content $projectFile -Raw -Encoding UTF8 | ConvertFrom-Json
$database = $project.databases | Where-Object { $_.id -eq $DatabaseId } | Select-Object -First 1

if (-not $database) {
    Write-Host "Ошибка: база $DatabaseId не найдена в .v8-project.json" -ForegroundColor Red
    exit 1
}

if (-not $UserName) {
    $localProjectFile = Join-Path $workspaceRoot ".v8-project.local.json"
    if (Test-Path $localProjectFile) {
        $localProject = Get-Content $localProjectFile -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($localProject.sshUser) {
            $UserName = $localProject.sshUser
            Write-Host "Пользователь из .v8-project.local.json: $UserName" -ForegroundColor DarkGray
        }
    }
}

if (-not $UserName) {
    $UserName = Read-Host "Пользователь информационной базы"
}

if ([string]::IsNullOrWhiteSpace($UserName)) {
    Write-Host "Ошибка: не указан пользователь информационной базы" -ForegroundColor Red
    exit 1
}

$securePassword = Read-Host "Пароль пользователя информационной базы" -AsSecureString
if ($null -eq $securePassword -or $securePassword.Length -eq 0) {
    Write-Host "Ошибка: не указан пароль пользователя информационной базы" -ForegroundColor Red
    exit 1
}

$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
try {
    $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
}

$sourceFileFull = (Resolve-Path $sourceFile).Path
$outputFileFull = [System.IO.Path]::GetFullPath($OutputFile)
$outputDir = Split-Path $outputFileFull -Parent

if ($outputDir -and -not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
}

Write-Host ""
Write-Host "=== Сборка EPF ===" -ForegroundColor Cyan
Write-Host "Обработка : $ProcessorName" -ForegroundColor Cyan
Write-Host "Источник  : $sourceFileFull" -ForegroundColor Cyan
Write-Host "Результат : $outputFileFull" -ForegroundColor Cyan
Write-Host "База      : $($database.server)/$($database.ref)" -ForegroundColor Cyan
Write-Host ""

$buildParams = @{
    V8Path       = $project.v8path
    SourceFile   = $sourceFileFull
    OutputFile   = $outputFileFull
    UserName     = $UserName
    Password     = $plainPassword
}

if ($database.type -eq "file" -or $database.path) {
    $buildParams.InfoBasePath = $database.path
} else {
    $buildParams.InfoBaseServer = $database.server
    $buildParams.InfoBaseRef = $database.ref
}

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

try {
    & $buildScript @buildParams
    if ($LASTEXITCODE -ne 0) {
        throw "Сборка завершилась с кодом $LASTEXITCODE"
    }
} catch {
    Write-Host ""
    Write-Host "Ошибка сборки: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    $stopwatch.Stop()
}

if (-not (Test-Path $outputFileFull)) {
    Write-Host "Ошибка: файл EPF не создан: $outputFileFull" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Сборка завершена: $outputFileFull" -ForegroundColor Green
Write-Host ("Время сборки: {0:N1} с" -f $stopwatch.Elapsed.TotalSeconds) -ForegroundColor Cyan

if (-not [string]::IsNullOrWhiteSpace($CopyToDir)) {
    try {
        if (-not (Test-Path $CopyToDir)) {
            New-Item -ItemType Directory -Force -Path $CopyToDir | Out-Null
        }

        $targetPath = Join-Path $CopyToDir (Split-Path $outputFileFull -Leaf)
        Copy-Item -LiteralPath $outputFileFull -Destination $targetPath -Force
        Write-Host "Файл скопирован: $targetPath" -ForegroundColor Green
    } catch {
        Write-Host "Не удалось скопировать файл в $CopyToDir : $($_.Exception.Message)" -ForegroundColor Red
    }
}

exit 0
