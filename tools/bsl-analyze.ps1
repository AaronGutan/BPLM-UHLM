param(
    [string]$SourceDir = "$PSScriptRoot\..\src",
    [string]$OutputDir = "$PSScriptRoot\..\src\bsl-reports",
    [string]$ConfigFile = "$PSScriptRoot\..\.bsl-language-server.json",
    [string]$JarPath = "E:\1C\AY\1c-syntax\bsl-language-server\build\libs\bsl-language-server-0.25.0-ra.12.0-SNAPSHOT-DIRTY-exec.jar"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $JarPath)) {
    throw "JAR не найден: $JarPath"
}

if (-not (Test-Path $SourceDir)) {
    throw "Каталог исходников не найден: $SourceDir"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$args = @(
    "-Xmx4g",
    "-jar", $JarPath,
    "analyze",
    "-s", (Resolve-Path $SourceDir).Path,
    "-w", (Resolve-Path $SourceDir).Path,
    "-o", (Resolve-Path $OutputDir).Path,
    "-r", "console",
    "-r", "json"
)

if (Test-Path $ConfigFile) {
    $args += @("-c", (Resolve-Path $ConfigFile).Path)
}

Push-Location (Resolve-Path $SourceDir).Path
try {
    & java @args
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
