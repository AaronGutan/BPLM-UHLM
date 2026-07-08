# Сборка CFE: загрузка XML-исходников расширения и выгрузка .cfe
param(
    [string]$ConfigDir,
    [string]$Extension,
    [string]$OutputFile,
    [string]$DatabaseId = "uh-lm",
    [string]$AgentPort = "1543",
    [string]$SshUser,
    [switch]$SkipVersionUpdate,
    [switch]$UseAgentMode,
    [switch]$StopAgent,
    [switch]$RestartAgent,
    [switch]$KeepAgentConnected,
    [switch]$DebugAgent,
    [switch]$PauseBetweenCommands,
    [switch]$RecreateExtension,
    [string]$AgentCommand,
    [string]$CopyToDir = "S:\1C Dev\LM\BPLM-UHLM",
    [switch]$Visible
)

$ErrorActionPreference = "Stop"

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
$projectFile = Join-Path $workspaceRoot ".v8-project.json"
$agentBaseDir = Join-Path $workspaceRoot ".vscode/agent-base"
$agentLinkName = "cfe-src"

if (-not $ConfigDir) {
    $ConfigDir = Join-Path $workspaceRoot "acclmcopy-cfe-consolidation"
}

if (-not (Test-Path $ConfigDir)) {
    Write-Host "Ошибка: каталог исходников расширения не найден: $ConfigDir" -ForegroundColor Red
    exit 1
}

$configurationXml = Join-Path $ConfigDir "Configuration.xml"
if (-not (Test-Path $configurationXml)) {
    Write-Host "Ошибка: Configuration.xml не найден в $ConfigDir" -ForegroundColor Red
    exit 1
}

[xml]$configuration = Get-Content $configurationXml -Encoding UTF8
$ns = New-Object System.Xml.XmlNamespaceManager($configuration.NameTable)
$ns.AddNamespace("md", "http://v8.1c.ru/8.3/MDClasses")

$propertiesNode = $configuration.SelectSingleNode("//md:Configuration/md:Properties", $ns)
if (-not $propertiesNode) {
    Write-Host "Ошибка: узел Properties не найден в Configuration.xml" -ForegroundColor Red
    exit 1
}

if (-not $Extension) {
    $nameNode = $propertiesNode.SelectSingleNode("md:Name", $ns)
    if (-not $nameNode -or [string]::IsNullOrWhiteSpace($nameNode.InnerText)) {
        Write-Host "Ошибка: имя расширения не найдено в Configuration.xml" -ForegroundColor Red
        exit 1
    }

    $Extension = $nameNode.InnerText
}

$versionNode = $propertiesNode.SelectSingleNode("md:Version", $ns)
if (-not $versionNode) {
    Write-Host "Ошибка: Version не найден в Configuration.xml" -ForegroundColor Red
    exit 1
}

# Назначение расширения из файлов. Нужно для команды агента config extensions create,
# где значение задаётся в нижнем регистре с дефисом (add-on, customization, patch).
$purposeNode = $propertiesNode.SelectSingleNode("md:ConfigurationExtensionPurpose", $ns)
$extensionPurposeSource = if ($purposeNode) { $purposeNode.InnerText.Trim() } else { "Customization" }
$extensionPurposeMap = @{
    "AddOn"         = "add-on"
    "Customization" = "customization"
    "Patch"         = "patch"
}
$extensionPurposeAgent = $extensionPurposeMap[$extensionPurposeSource]
if ([string]::IsNullOrWhiteSpace($extensionPurposeAgent)) {
    $extensionPurposeAgent = "customization"
}

function Get-VersionDateKey {
    param(
        [string]$Year,
        [string]$Month,
        [string]$Day
    )

    if ($Year.Length -eq 4) {
        $Year = $Year.Substring(2)
    }

    return "${Year}_${Month}_${Day}"
}

function Get-NextExtensionVersion {
    param(
        [string]$CurrentVersion,
        [string]$Today
    )

    $buildNumber = 1
    $versionPattern = "^(\d{2,4})[_-](\d{2})[_-](\d{2})(?:_?v(\d+))?$"

    if ($CurrentVersion -match $versionPattern) {
        $currentDate = Get-VersionDateKey -Year $Matches[1] -Month $Matches[2] -Day $Matches[3]
        $buildNumber = if ($Matches[4]) { [int]$Matches[4] } else { 0 }

        if ($currentDate -eq $Today) {
            $buildNumber += 1
        } else {
            $buildNumber = 1
        }
    }

    return "${Today}_v${buildNumber}"
}

function Test-TcpPortOpen {
    param(
        [string]$HostName,
        [int]$Port
    )

    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $client.Connect($HostName, $Port)
        return $true
    } catch {
        return $false
    } finally {
        if ($client.Connected) {
            $client.Close()
        }
    }
}

function Wait-AgentPort {
    param(
        [int]$Port,
        [int]$TimeoutSec
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        if (Test-TcpPortOpen -HostName "127.0.0.1" -Port $Port) {
            return $true
        }

        Start-Sleep -Milliseconds 500
    }

    return $false
}

function Get-AgentUserDirectory {
    param(
        [string]$AgentBaseDirectory,
        [string]$UserName
    )

    $jsonPath = Join-Path $AgentBaseDirectory "agentbasedir.json"
    if (Test-Path $jsonPath) {
        $json = Get-Content $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json

        # Сначала ищем точное совпадение логина с учётом регистра,
        # так как агент создаёт отдельные каталоги для разного написания имени.
        foreach ($userInfo in $json.usersInfo) {
            if ($userInfo.name -ceq $UserName) {
                return $userInfo.dir
            }
        }

        # Резервный вариант — без учёта регистра.
        foreach ($userInfo in $json.usersInfo) {
            if ($userInfo.name -ieq $UserName) {
                Write-Host "Внимание: точного совпадения логина ""$UserName"" в agentbasedir.json нет, используется ""$($userInfo.name)"" (каталог $($userInfo.dir))." -ForegroundColor Yellow
                return $userInfo.dir
            }
        }
    }

    return "0"
}

function Ensure-AgentSourceLink {
    param(
        [string]$AgentBaseDirectory,
        [string]$LinkName,
        [string]$TargetDirectory
    )

    New-Item -ItemType Directory -Force -Path $AgentBaseDirectory | Out-Null

    $linkPath = Join-Path $AgentBaseDirectory $LinkName
    $targetFull = (Resolve-Path $TargetDirectory).Path

    if (Test-Path $linkPath) {
        $existingTarget = (Get-Item $linkPath).Target
        if ($existingTarget -and ($existingTarget -eq $targetFull)) {
            return $LinkName
        }

        Remove-Item $linkPath -Force -Recurse
    }

    New-Item -ItemType Junction -Path $linkPath -Target $targetFull | Out-Null
    return $LinkName
}

function Format-BuildDuration {
    param(
        [TimeSpan]$Duration
    )

    if ($Duration.TotalHours -ge 1) {
        return ("{0:N0} ч {1:N0} мин {2:N1} с" -f [math]::Floor($Duration.TotalHours), $Duration.Minutes, $Duration.Seconds)
    }

    if ($Duration.TotalMinutes -ge 1) {
        return ("{0:N0} мин {1:N1} с" -f [math]::Floor($Duration.TotalMinutes), $Duration.Seconds)
    }

    return ("{0:N1} с" -f $Duration.TotalSeconds)
}

# Копирует собранный файл CFE в целевой каталог (например, сетевую папку).
# Ошибка копирования не должна прерывать сборку, поэтому обрабатывается отдельно.
function Copy-BuildArtifact {
    param(
        [string]$SourcePath,
        [string]$TargetDirectory
    )

    if ([string]::IsNullOrWhiteSpace($TargetDirectory)) {
        return
    }

    if (-not (Test-Path $SourcePath)) {
        Write-Host "Копирование пропущено: исходный файл не найден ($SourcePath)." -ForegroundColor Yellow
        return
    }

    try {
        if (-not (Test-Path $TargetDirectory)) {
            New-Item -ItemType Directory -Force -Path $TargetDirectory | Out-Null
        }

        $fileName = Split-Path $SourcePath -Leaf
        $targetPath = Join-Path $TargetDirectory $fileName
        Copy-Item -LiteralPath $SourcePath -Destination $targetPath -Force
        Write-Host "Файл скопирован: $targetPath" -ForegroundColor Green
    } catch {
        Write-Host "Не удалось скопировать файл в $TargetDirectory : $($_.Exception.Message)" -ForegroundColor Red
    }
}

function ConvertTo-PlainText {
    param(
        [Security.SecureString]$SecureString
    )

    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function Invoke-DesignerBatchBuild {
    param(
        [string]$V8Path,
        [object]$Database,
        [string]$User,
        [Security.SecureString]$Password,
        [string]$ConfigDirectory,
        [string]$OutputPath,
        [string]$ExtensionName
    )

    $plainPassword = ConvertTo-PlainText $Password
    $logFile = Join-Path $env:TEMP "1c-cfe-build.log"
    $resultFile = Join-Path $env:TEMP "1c-cfe-build-result.txt"

    if (Test-Path $logFile) {
        Remove-Item $logFile -Force
    }

    if (Test-Path $resultFile) {
        Remove-Item $resultFile -Force
    }

    # -UpdateConfigDumpInfo обязателен: иначе при следующем запуске платформа
    # может опереться на устаревший ConfigDumpInfo.xml и не подхватить модули.
    # /UpdateDBCfg для расширения применяет загруженную конфигурацию перед DumpCfg.
    $arguments = @(
        "DESIGNER",
        "/S", "`"$($Database.server)/$($Database.ref)`"",
        "/N", "`"$User`"",
        "/P", "`"$plainPassword`"",
        "/WA-",
        "/DisableStartupDialogs",
        "/LoadConfigFromFiles", "`"$ConfigDirectory`"",
        "-Extension", "`"$ExtensionName`"",
        "-UpdateConfigDumpInfo",
        "/UpdateDBCfg",
        "-Extension", "`"$ExtensionName`"",
        "/DumpCfg", "`"$OutputPath`"",
        "-Extension", "`"$ExtensionName`"",
        "/Out", "`"$logFile`"",
        "/DumpResult", "`"$resultFile`""
    )

    Write-Host "Запуск конфигуратора (пакетный режим)..." -ForegroundColor Green

    $process = Start-Process -FilePath $V8Path -ArgumentList $arguments -Wait -PassThru -NoNewWindow

    if (Test-Path $logFile) {
        Write-Host ""
        Write-Host "--- Журнал конфигуратора ---" -ForegroundColor DarkGray
        Get-Content $logFile -Encoding UTF8 | ForEach-Object { Write-Host $_ }
        Write-Host "--- конец журнала ---" -ForegroundColor DarkGray
        Write-Host ""
    }

    $resultCode = 1
    if (Test-Path $resultFile) {
        $resultText = (Get-Content $resultFile -Raw -Encoding UTF8).Trim()
        if ($resultText -match "^\d+$") {
            $resultCode = [int]$resultText
        }
    }

    if ($resultCode -ne 0) {
        throw "Пакетная сборка завершилась с кодом $resultCode. См. $logFile"
    }

    if ($process.ExitCode -ne 0) {
        throw "Конфигуратор завершился с кодом $($process.ExitCode). См. $logFile"
    }
}

function Set-SshAskPass {
    param(
        [Security.SecureString]$Password
    )

    $askPassCmd = Join-Path $env:TEMP "1c-ssh-askpass.cmd"
    @'
@echo off
echo %ONEC_SSH_PASS%
'@ | Set-Content -LiteralPath $askPassCmd -Encoding ASCII

    $env:ONEC_SSH_PASS = ConvertTo-PlainText $Password
    $env:SSH_ASKPASS = $askPassCmd
    $env:SSH_ASKPASS_REQUIRE = "force"

    if (-not $env:DISPLAY) {
        $env:DISPLAY = "1c:0"
    }
}

function Clear-SshAskPass {
    Remove-Item Env:ONEC_SSH_PASS -ErrorAction SilentlyContinue
    Remove-Item Env:SSH_ASKPASS -ErrorAction SilentlyContinue
    Remove-Item Env:SSH_ASKPASS_REQUIRE -ErrorAction SilentlyContinue
}

function New-AgentStreamState {
    param(
        [System.IO.StreamReader]$Reader
    )

    return [PSCustomObject]@{
        Reader  = $Reader
        Buffer  = New-Object char[] 8192
        Pending = $null
        Closed  = $false
    }
}

# Неблокирующее посимвольное чтение потока.
# Возвращает прочитанный текст ("" если данных пока нет).
# Флаг Closed выставляется при достижении конца потока.
function Read-AgentStreamText {
    param(
        [PSCustomObject]$State,
        [int]$TimeoutMs = 100
    )

    if ($null -eq $State -or $State.Closed) {
        return ""
    }

    try {
        if ($null -eq $State.Pending) {
            $State.Pending = $State.Reader.ReadAsync($State.Buffer, 0, $State.Buffer.Length)
        }

        if ($State.Pending.Wait($TimeoutMs)) {
            $count = $State.Pending.Result
            $State.Pending = $null

            if ($count -le 0) {
                $State.Closed = $true
                return ""
            }

            return (New-Object string($State.Buffer, 0, $count))
        }
    } catch {
        $State.Closed = $true
        return ""
    }

    return ""
}

function Read-DesignerAgentOutput {
    param(
        [PSCustomObject]$StdoutState,
        [PSCustomObject]$StderrState,
        [System.Text.StringBuilder]$AllOutput,
        [int]$TimeoutSec = 600,
        [switch]$DebugAgent
    )

    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSec)
    $startedAt = [DateTime]::UtcNow
    $builder = New-Object System.Text.StringBuilder
    $lastHeartbeat = [DateTime]::UtcNow

    while ([DateTime]::UtcNow -lt $deadline) {
        $errText = Read-AgentStreamText -State $StderrState -TimeoutMs 30
        if ($errText) {
            [void]$builder.Append($errText)
            [void]$AllOutput.Append($errText)
            Write-Host $errText -ForegroundColor Yellow -NoNewline
        }

        $outText = Read-AgentStreamText -State $StdoutState -TimeoutMs 100
        if ($outText) {
            [void]$builder.Append($outText)
            [void]$AllOutput.Append($outText)
            Write-Host $outText -NoNewline
        }

        $text = $builder.ToString()

        if ($text -match "Операция завершена успешно" `
            -or $text -match "DesignerNotConnectedToInfoBase" `
            -or $text -match "Ошибка Designer" `
            -or $text -match "Ошибка [A-Za-zА-Яа-я]") {
            Start-Sleep -Milliseconds 200
            $tail = Read-AgentStreamText -State $StdoutState -TimeoutMs 100
            if ($tail) {
                [void]$AllOutput.Append($tail)
                Write-Host $tail -NoNewline
                [void]$builder.Append($tail)
            }
            Write-Host ""
            return $builder.ToString()
        }

        # Приглашение появляется без перевода строки — ищем как подстроку.
        if ($text -match "designer>\s*$") {
            Write-Host ""
            return $builder.ToString()
        }

        if ($DebugAgent -and ([DateTime]::UtcNow - $lastHeartbeat).TotalSeconds -ge 10) {
            $elapsed = [int](([DateTime]::UtcNow - $startedAt).TotalSeconds)
            Write-Host "  ... ожидание ответа ($elapsed с)" -ForegroundColor DarkGray
            $lastHeartbeat = [DateTime]::UtcNow
        }

        if ($StdoutState.Closed -and $StderrState.Closed) {
            Write-Host ""
            return $builder.ToString()
        }
    }

    Write-Host ""
    throw "Таймаут ожидания ответа агента (${TimeoutSec} с). Получено:`n$($builder.ToString())"
}

function Wait-DesignerAgentShell {
    param(
        [PSCustomObject]$StdoutState,
        [PSCustomObject]$StderrState,
        [System.Text.StringBuilder]$AllOutput,
        [int]$TimeoutSec = 120,
        [switch]$DebugAgent
    )

    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSec)
    $builder = New-Object System.Text.StringBuilder
    $lastHeartbeat = [DateTime]::UtcNow
    $startedAt = [DateTime]::UtcNow

    while ([DateTime]::UtcNow -lt $deadline) {
        $errText = Read-AgentStreamText -State $StderrState -TimeoutMs 30
        if ($errText) {
            [void]$builder.Append($errText)
            [void]$AllOutput.Append($errText)
            Write-Host $errText -ForegroundColor Yellow -NoNewline
        }

        $outText = Read-AgentStreamText -State $StdoutState -TimeoutMs 100
        if ($outText) {
            [void]$builder.Append($outText)
            [void]$AllOutput.Append($outText)
            Write-Host $outText -NoNewline
        }

        $combined = $builder.ToString()

        # Ждём именно приглашение designer> (в конце), чтобы полностью
        # вычитать стартовый баннер и приглашение из потока. Иначе остаток
        # приглашения будет ошибочно принят за результат первой команды.
        if ($combined -match "designer>\s*$") {
            Write-Host ""
            return $combined
        }

        if ($combined -match "Permission denied|Authentication failed|Access denied|Неверный пароль") {
            Write-Host ""
            throw "SSH-аутентификация не прошла. Проверьте логин и пароль пользователя 1С.`n$combined"
        }

        if ($DebugAgent -and ([DateTime]::UtcNow - $lastHeartbeat).TotalSeconds -ge 10) {
            $elapsed = [int](([DateTime]::UtcNow - $startedAt).TotalSeconds)
            Write-Host "  ... ожидание designer> ($elapsed с)" -ForegroundColor DarkGray
            $lastHeartbeat = [DateTime]::UtcNow
        }

        if ($StdoutState.Closed -and $StderrState.Closed) {
            Write-Host ""
            throw "SSH-соединение закрылось до появления оболочки. Получено:`n$($builder.ToString())"
        }
    }

    Write-Host ""
    throw "Агент не выдал приглашение designer> за ${TimeoutSec} с. Получено:`n$($builder.ToString())"
}

function Test-DesignerAgentCommandResult {
    param(
        [string]$CommandOutput,
        [string]$Command
    )

    if ($CommandOutput -match "DesignerNotConnectedToInfoBase|Ошибка Designer|Ошибка [A-Za-zА-Яа-я]") {
        return [PSCustomObject]@{
            Success = $false
            Message = "Агент сообщил об ошибке"
        }
    }

    # Для изменяющих команд недостаточно простого возврата к prompt designer>:
    # при сбое загрузки/выгрузки ответ мог выглядеть «успешным», а CFE оставался старым.
    $mutatingCommand = $Command -match "^\s*config\s+(load-|dump-|update-db-cfg|extensions\s+(delete|create))"
    if ($mutatingCommand) {
        if ($CommandOutput -match "Операция завершена успешно") {
            return [PSCustomObject]@{
                Success = $true
                Message = "OK"
            }
        }

        return [PSCustomObject]@{
            Success = $false
            Message = "Нет подтверждения «Операция завершена успешно»"
        }
    }

    if ($CommandOutput -match "Операция завершена успешно|designer>\s*$") {
        return [PSCustomObject]@{
            Success = $true
            Message = "OK"
        }
    }

    return [PSCustomObject]@{
        Success = $false
        Message = "Неожиданный ответ агента"
    }
}

function Invoke-DesignerAgentCommands {
    param(
        [string]$User,
        [int]$Port,
        [string[]]$Commands,
        [Security.SecureString]$Password,
        [int]$CommandTimeoutSec = 600,
        [switch]$DebugAgent,
        [switch]$PauseBetweenCommands
    )

    if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
        throw "Клиент OpenSSH не найден. Установите компонент OpenSSH Client в Windows."
    }

    $target = "${User}@127.0.0.1"
    $commandTotal = $Commands.Count

    Write-Host ""
    Write-Host "Подключение к агенту по SSH (порт $Port)..." -ForegroundColor Green
    Write-Host "Пользователь: $User" -ForegroundColor DarkGray
    if ($DebugAgent) {
        Write-Host "SSH: ssh -T -p $Port `"$target`"" -ForegroundColor DarkGray
        Write-Host "Команд к выполнению: $commandTotal" -ForegroundColor DarkGray
    }
    Write-Host ""

    Set-SshAskPass -Password $Password

    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = "ssh"
    $processInfo.Arguments = "-T -p $Port -o StrictHostKeyChecking=accept-new -o BatchMode=no `"$target`""
    $processInfo.UseShellExecute = $false
    $processInfo.RedirectStandardInput = $true
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError = $true
    $processInfo.CreateNoWindow = $true
    $processInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $processInfo.StandardErrorEncoding = [System.Text.Encoding]::UTF8

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processInfo

    $allOutput = New-Object System.Text.StringBuilder
    $commandResults = New-Object System.Collections.Generic.List[object]

    try {
        if (-not $process.Start()) {
            throw "Не удалось запустить ssh"
        }

        # Команды агенту передаём строго в UTF-8 (без BOM). В PowerShell 5.1
        # у ProcessStartInfo нет StandardInputEncoding, поэтому writer по умолчанию
        # пишет в кодовой странице консоли и искажает кириллицу в именах расширений
        # (имя "Консолидация" уходило агенту нечитаемым — отсюда ExtensionNotFound
        # при delete и UnknownError при load-config-from-files).
        $stdinEncoding = New-Object System.Text.UTF8Encoding($false)
        $stdin = New-Object System.IO.StreamWriter($process.StandardInput.BaseStream, $stdinEncoding)
        $stdin.AutoFlush = $true
        $stdoutState = New-AgentStreamState -Reader $process.StandardOutput
        $stderrState = New-AgentStreamState -Reader $process.StandardError

        Write-Host "[SSH] Ожидание оболочки designer>..." -ForegroundColor Cyan
        $shellStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        Wait-DesignerAgentShell -StdoutState $stdoutState -StderrState $stderrState -AllOutput $allOutput -TimeoutSec 120 -DebugAgent:$DebugAgent | Out-Null
        $shellStopwatch.Stop()
        Write-Host ("[SSH] Оболочка готова за {0}" -f (Format-BuildDuration -Duration $shellStopwatch.Elapsed)) -ForegroundColor Green
        Write-Host ""

        $commandIndex = 0
        foreach ($command in $Commands) {
            $commandIndex++
            Write-Host ("[{0}/{1}] >>> {2}" -f $commandIndex, $commandTotal, $command) -ForegroundColor Cyan

            if ($PauseBetweenCommands -and $commandIndex -gt 1) {
                Read-Host "Enter — отправить команду"
            } elseif ($PauseBetweenCommands) {
                Read-Host "Enter — отправить первую команду"
            }

            $commandStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $stdin.WriteLine($command)
            $stdin.Flush()

            $commandOutput = Read-DesignerAgentOutput `
                -StdoutState $stdoutState `
                -StderrState $stderrState `
                -AllOutput $allOutput `
                -TimeoutSec $CommandTimeoutSec `
                -DebugAgent:$DebugAgent

            $commandStopwatch.Stop()
            $result = Test-DesignerAgentCommandResult -CommandOutput $commandOutput -Command $command

            # Удаление расширения перед пересозданием не критично: если расширения
            # ещё нет в базе, агент вернёт ошибку, которую следует игнорировать.
            if (-not $result.Success -and $command -match "extensions delete") {
                Write-Host ("[{0}/{1}] <<< расширение не удалено (вероятно, отсутствует) — продолжаем" -f `
                    $commandIndex, $commandTotal) -ForegroundColor DarkYellow
                $result = [PSCustomObject]@{ Success = $true; Message = "пропущено" }
            }

            $commandResults.Add([PSCustomObject]@{
                Index    = $commandIndex
                Command  = $command
                Success  = $result.Success
                Duration = $commandStopwatch.Elapsed
                Output   = $commandOutput
            })

            if ($result.Success) {
                Write-Host ("[{0}/{1}] <<< OK за {2}" -f `
                    $commandIndex, $commandTotal, (Format-BuildDuration -Duration $commandStopwatch.Elapsed)) -ForegroundColor Green
            } else {
                Write-Host ("[{0}/{1}] <<< ОШИБКА за {2}: {3}" -f `
                    $commandIndex, $commandTotal, `
                    (Format-BuildDuration -Duration $commandStopwatch.Elapsed), `
                    $result.Message) -ForegroundColor Red
                if ($DebugAgent) {
                    Write-Host "--- ответ агента ---" -ForegroundColor DarkGray
                    Write-Host $commandOutput
                    Write-Host "--------------------" -ForegroundColor DarkGray

                    # Автодиагностика: если упала загрузка расширения, показываем,
                    # какие расширения фактически есть в подключённой базе.
                    if ($command -match "load-config-from-files|dump-cfg") {
                        Write-Host "Диагностика: список расширений в подключённой базе..." -ForegroundColor Magenta
                        try {
                            $stdin.WriteLine("config extensions properties get --all-extensions")
                            $stdin.Flush()
                            $diagOutput = Read-DesignerAgentOutput `
                                -StdoutState $stdoutState `
                                -StderrState $stderrState `
                                -AllOutput $allOutput `
                                -TimeoutSec 60 `
                                -DebugAgent:$DebugAgent
                            Write-Host "--- расширения в базе ---" -ForegroundColor DarkGray
                            Write-Host $diagOutput
                            Write-Host "-------------------------" -ForegroundColor DarkGray
                        } catch {
                            Write-Host "Не удалось получить список расширений: $($_.Exception.Message)" -ForegroundColor DarkGray
                        }
                    }
                }

                throw "Команда [$commandIndex/$commandTotal] не выполнена: $command`n$commandOutput"
            }

            Write-Host ""
        }

        # Команды выполнены и проверены. Закрываем ввод; агент в режиме
        # -KeepAgentConnected может не завершать SSH-сессию по EOF, поэтому
        # код возврата ssh здесь не считаем ошибкой.
        try {
            $stdin.Close()
        } catch {
            # Поток уже закрыт
        }

        if (-not $process.WaitForExit(5000)) {
            if ($DebugAgent) {
                Write-Host "[SSH] Сессия не завершилась по EOF, закрываем принудительно." -ForegroundColor DarkGray
            }
            $process.Kill()
        }
    } finally {
        Clear-SshAskPass

        if ($null -ne $process -and -not $process.HasExited) {
            $process.Kill()
        }

        if ($null -ne $process) {
            $process.Dispose()
        }
    }

    Write-Host "=== Итог выполнения команд агента ===" -ForegroundColor Magenta
    foreach ($item in $commandResults) {
        $status = if ($item.Success) { "OK" } else { "ОШИБКА" }
        $color = if ($item.Success) { [ConsoleColor]::Green } else { [ConsoleColor]::Red }
        Write-Host ("  [{0}/{1}] {2,-8} {3}" -f `
            $item.Index, $commandTotal, $status, (Format-BuildDuration -Duration $item.Duration)) -ForegroundColor $color
        Write-Host ("           {0}" -f $item.Command) -ForegroundColor DarkGray
    }
    Write-Host ""

    $outputText = $allOutput.ToString()
    $failedCount = @($commandResults | Where-Object { -not $_.Success }).Count
    if ($failedCount -gt 0) {
        throw "Ошибок выполнения команд: $failedCount из $commandTotal"
    }
}

function Invoke-CfeAgentBuild {
    param(
        [string]$V8Path,
        [object]$Database,
        [string]$User,
        [Security.SecureString]$Password,
        [string]$AgentBaseDirectory,
        [string]$AgentPort,
        [string]$ConfigDirRel,
        [string]$OutputFileRel,
        [string]$ExtensionName,
        [switch]$RestartAgent,
        [switch]$StopAgent,
        [switch]$KeepAgentConnected,
        [switch]$DebugAgent,
        [switch]$PauseBetweenCommands,
        [switch]$RecreateExtension,
        [string]$ExtensionPurpose,
        [string[]]$AgentCommandsOverride,
        [switch]$Visible
    )

    $agentPortNumber = [int]$AgentPort
    $agentWasRunning = Test-TcpPortOpen -HostName "127.0.0.1" -Port $agentPortNumber
    $databaseConnection = "$($Database.server)/$($Database.ref)"

    if ($RestartAgent -and $agentWasRunning) {
        Write-Host "Перезапуск агента: закрытие процесса на порту $AgentPort..." -ForegroundColor Yellow
        try {
            Set-SshAskPass -Password $Password
            & ssh -T -p $AgentPort -o StrictHostKeyChecking=accept-new -o BatchMode=no "`"${User}@127.0.0.1`"" "common shutdown" 2>$null | Out-Null
        } catch {
            # Игнорируем ошибки при остановке зависшего агента
        } finally {
            Clear-SshAskPass
        }

        Start-Sleep -Seconds 2
        $agentWasRunning = $false
    }

    if (-not $agentWasRunning) {
        $agentArguments = @(
            "DESIGNER",
            "/S", "`"$($Database.server)/$($Database.ref)`"",
            "/AgentMode",
            "/AgentSSHHostKeyAuto",
            "/AgentBaseDir", "`"$AgentBaseDirectory`"",
            "/AgentPort", $AgentPort
        )

        if ($Visible) {
            $agentArguments += "/Visible"
        }

        Write-Host "Запуск агента конфигуратора..." -ForegroundColor Green
        Write-Host "  База агента: $databaseConnection" -ForegroundColor Cyan
        Start-Process -FilePath $V8Path -ArgumentList $agentArguments | Out-Null

        if (-not (Wait-AgentPort -Port $agentPortNumber -TimeoutSec 120)) {
            throw "Агент не ответил на порту $AgentPort за 120 секунд"
        }

        Write-Host "Агент запущен для базы: $databaseConnection" -ForegroundColor Green
    } else {
        Write-Host "Агент уже слушает порт $AgentPort, используем существующий процесс." -ForegroundColor Yellow
        Write-Host "  Ожидаемая база: $databaseConnection" -ForegroundColor Cyan
        Write-Host "  Внимание: работающий агент подключён к базе, с которой был запущен ранее." -ForegroundColor Yellow
        Write-Host "  Если база отличается — перезапустите сборку с параметром -RestartAgent." -ForegroundColor Yellow
    }

    if ($AgentCommandsOverride -and $AgentCommandsOverride.Count -gt 0) {
        $agentCommands = $AgentCommandsOverride
        Write-Host "Режим отладки: выполняется заданный набор команд ($($agentCommands.Count))." -ForegroundColor Yellow
    } else {
        # Имена и пути передаются в шелл агента без кавычек: его парсер
        # не срезает двойные кавычки, из-за чего имя расширения "Консолидация"
        # воспринималось буквально с кавычками (ошибка UnknownError).
        $agentCommands = @(
            "common connect-ib",
            "options set --show-prompt=no --output-format=text"
        )

        # Пересоздание расширения: в базе может остаться пустое расширение
        # с несовпадающим назначением (например customization вместо add-on),
        # из-за чего load-config-from-files падает с UnknownError. Удаляем его
        # (ошибка удаления несуществующего расширения не критична). Отдельная
        # команда create не нужна: load-config-from-files создаёт расширение
        # автоматически и берёт назначение из Configuration.xml.
        if ($RecreateExtension) {
            Write-Host "Расширение будет пересоздано загрузкой из файлов (назначение $ExtensionPurpose)." -ForegroundColor Yellow
            $agentCommands += "config extensions delete --extension=$ExtensionName"
        }

        # --update-config-dump-info: после загрузки ConfigDumpInfo.xml приводится
        # в соответствие с файлами. Иначе при следующих сборках платформа может
        # считать модули «неизменёнными» по устаревшим хешам и не включать их в CFE.
        # update-db-cfg: применяет расширение в конфигурации БД до выгрузки dump-cfg.
        $agentCommands += "config load-config-from-files --dir=$ConfigDirRel --extension=$ExtensionName --update-config-dump-info"
        $agentCommands += "config update-db-cfg --extension=$ExtensionName"
        $agentCommands += "config dump-cfg --file=$OutputFileRel --extension=$ExtensionName"

        if (-not $KeepAgentConnected) {
            $agentCommands += "common disconnect-ib"
        } else {
            Write-Host "disconnect-ib пропущен — агент останется подключен к ИБ." -ForegroundColor DarkGray
        }
    }

    if ($StopAgent) {
        $agentCommands += "common shutdown"
    }

    Invoke-DesignerAgentCommands `
        -User $User `
        -Port $agentPortNumber `
        -Commands $agentCommands `
        -Password $Password `
        -DebugAgent:$DebugAgent `
        -PauseBetweenCommands:$PauseBetweenCommands

    if (-not $StopAgent -and -not $agentWasRunning) {
        Write-Host "Агент оставлен запущенным (повторные сборки будут быстрее)." -ForegroundColor DarkGray
    }
}

function Invoke-CfeBuildCore {
    param(
        [bool]$AgentMode,
        [string]$V8Path,
        [object]$Database,
        [string]$User,
        [Security.SecureString]$Password,
        [string]$ConfigDirectory,
        [string]$OutputPath,
        [string]$ExtensionName,
        [string]$AgentBaseDirectory,
        [string]$AgentPort,
        [string]$ConfigDirRel,
        [string]$OutputFileRel,
        [switch]$RestartAgent,
        [switch]$StopAgent,
        [switch]$KeepAgentConnected,
        [switch]$DebugAgent,
        [switch]$PauseBetweenCommands,
        [switch]$RecreateExtension,
        [string]$ExtensionPurpose,
        [string[]]$AgentCommandsOverride,
        [switch]$AgentDebugOnly,
        [switch]$Visible
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        if ($AgentMode) {
            Invoke-CfeAgentBuild `
                -V8Path $V8Path `
                -Database $Database `
                -User $User `
                -Password $Password `
                -AgentBaseDirectory $AgentBaseDirectory `
                -AgentPort $AgentPort `
                -ConfigDirRel $ConfigDirRel `
                -OutputFileRel $OutputFileRel `
                -ExtensionName $ExtensionName `
                -RestartAgent:$RestartAgent `
                -StopAgent:$StopAgent `
                -KeepAgentConnected:$KeepAgentConnected `
                -DebugAgent:$DebugAgent `
                -PauseBetweenCommands:$PauseBetweenCommands `
                -RecreateExtension:$RecreateExtension `
                -ExtensionPurpose $ExtensionPurpose `
                -AgentCommandsOverride $AgentCommandsOverride `
                -Visible:$Visible
        } else {
            Invoke-DesignerBatchBuild `
                -V8Path $V8Path `
                -Database $Database `
                -User $User `
                -Password $Password `
                -ConfigDirectory $ConfigDirectory `
                -OutputPath $OutputPath `
                -ExtensionName $ExtensionName
        }
    } finally {
        $stopwatch.Stop()
    }

    if (-not $AgentDebugOnly -and -not (Test-Path $OutputPath)) {
        throw "Файл CFE не создан: $OutputPath"
    }

    return $stopwatch.Elapsed
}

function Initialize-AgentSourcePaths {
    param(
        [string]$AgentBaseDirectory,
        [string]$LinkName,
        [string]$TargetDirectory,
        [string]$UserName,
        [string]$ExtensionName,
        [string]$Version
    )

    $agentUserDir = Get-AgentUserDirectory -AgentBaseDirectory $AgentBaseDirectory -UserName $UserName
    $agentUserBase = Join-Path $AgentBaseDirectory $agentUserDir
    $configDirRel = Ensure-AgentSourceLink -AgentBaseDirectory $agentUserBase -LinkName $LinkName -TargetDirectory $TargetDirectory
    $outputFileRel = "$configDirRel/${ExtensionName}_${Version}.cfe" -replace "\\", "/"

    return [PSCustomObject]@{
        UserBase      = $agentUserBase
        ConfigDirRel  = $configDirRel
        OutputFileRel = $outputFileRel
    }
}

function Write-BuildModeHeader {
    param(
        [string]$ModeTitle,
        [string]$ExtensionName,
        [string]$Version,
        [string]$ConfigDirectory,
        [string]$OutputPath,
        [object]$Database,
        [string]$AgentPort,
        [string]$AgentUserBase
    )

    Write-Host ""
    Write-Host "=== Сборка CFE ($ModeTitle) ===" -ForegroundColor Cyan
    Write-Host "Расширение : $ExtensionName" -ForegroundColor Cyan
    Write-Host "Версия     : $Version" -ForegroundColor Cyan
    Write-Host "Источник   : $ConfigDirectory" -ForegroundColor Cyan
    Write-Host "Результат  : $OutputPath" -ForegroundColor Cyan
    Write-Host "База       : $($Database.server)/$($Database.ref)" -ForegroundColor Cyan

    if ($AgentUserBase) {
        Write-Host "Агент      : 127.0.0.1:$AgentPort" -ForegroundColor Cyan
        Write-Host "Каталог SFTP: $AgentUserBase" -ForegroundColor Cyan
    }

    Write-Host ""
}

$today = Get-Date -Format "yy_MM_dd"
if (-not $SkipVersionUpdate) {
    $oldVersion = $versionNode.InnerText
    $version = Get-NextExtensionVersion -CurrentVersion $oldVersion -Today $today

    if ($oldVersion -ne $version) {
        $utf8Bom = New-Object System.Text.UTF8Encoding $true
        $content = [System.IO.File]::ReadAllText($configurationXml, $utf8Bom)
        $versionTagPattern = "<Version>[^<]*</Version>"
        $newContent = [regex]::Replace($content, $versionTagPattern, "<Version>$version</Version>", 1)

        if ($newContent -eq $content) {
            Write-Host "Ошибка: не удалось обновить Version в Configuration.xml" -ForegroundColor Red
            exit 1
        }

        [System.IO.File]::WriteAllText($configurationXml, $newContent, $utf8Bom)
        Write-Host "Версия обновлена: $oldVersion -> $version" -ForegroundColor Yellow
    } else {
        $version = $oldVersion
    }
} else {
    $version = $versionNode.InnerText
}

if (-not $OutputFile) {
    $OutputFile = Join-Path $ConfigDir "${Extension}_${version}.cfe"
}

if (-not (Test-Path $projectFile)) {
    Write-Host "Ошибка: .v8-project.json не найден в корне проекта" -ForegroundColor Red
    exit 1
}

$project = Get-Content $projectFile -Raw -Encoding UTF8 | ConvertFrom-Json
$v8Path = $project.v8path
$database = $project.databases | Where-Object { $_.id -eq $DatabaseId } | Select-Object -First 1

if (-not $database) {
    Write-Host "Ошибка: база $DatabaseId не найдена в .v8-project.json" -ForegroundColor Red
    exit 1
}

if (-not $v8Path) {
    $found = Get-ChildItem "C:\Program Files\1cv8\*\bin\1cv8.exe" -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending |
        Select-Object -First 1
    if ($found) {
        $v8Path = $found.FullName
    } else {
        Write-Host "Ошибка: v8path не задан и 1cv8.exe не найден" -ForegroundColor Red
        exit 1
    }
} elseif (Test-Path $v8Path -PathType Container) {
    $v8Path = Join-Path $v8Path "1cv8.exe"
}

$configDirFull = (Resolve-Path $ConfigDir).Path
$outputFileFull = [System.IO.Path]::GetFullPath($OutputFile)

if (-not $SshUser) {
    $localProjectFile = Join-Path $workspaceRoot ".v8-project.local.json"
    if (Test-Path $localProjectFile) {
        $localProject = Get-Content $localProjectFile -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($localProject.sshUser) {
            $SshUser = $localProject.sshUser
            Write-Host "SSH-пользователь из .v8-project.local.json: $SshUser" -ForegroundColor DarkGray
        }
    }
}

if (-not $SshUser) {
    $SshUser = Read-Host "Пользователь информационной базы (логин 1С для SSH, напр. andrey yashchenko)"
}

if ([string]::IsNullOrWhiteSpace($SshUser)) {
    Write-Host "Ошибка: не указан пользователь информационной базы" -ForegroundColor Red
    exit 1
}

$SshPassword = Read-Host "Пароль пользователя информационной базы" -AsSecureString
if ($null -eq $SshPassword -or $SshPassword.Length -eq 0) {
    Write-Host "Ошибка: не указан пароль пользователя информационной базы" -ForegroundColor Red
    exit 1
}

$agentCommandsOverride = $null
$agentDebugOnly = $false

if ($AgentCommand) {
    $UseAgentMode = $true
    $SkipVersionUpdate = $true
    $agentDebugOnly = $true
    $DebugAgent = $true

    # Перед произвольной командой подключаемся к ИБ и включаем текстовый вывод,
    # чтобы диагностические команды (например, список расширений) работали.
    if ($AgentCommand -match "^\s*common connect-ib\s*$") {
        $agentCommandsOverride = @($AgentCommand)
    } else {
        $agentCommandsOverride = @(
            "common connect-ib",
            "options set --show-prompt=no --output-format=text",
            $AgentCommand
        )
    }

    Write-Host "Отладка команды агента: $AgentCommand" -ForegroundColor Yellow
}

$agentPaths = $null
if ($UseAgentMode) {
    $agentPaths = Initialize-AgentSourcePaths `
        -AgentBaseDirectory $agentBaseDir `
        -LinkName $agentLinkName `
        -TargetDirectory $configDirFull `
        -UserName $SshUser `
        -ExtensionName $Extension `
        -Version $version
}

$buildParams = @{
    V8Path                = $v8Path
    Database              = $database
    User                  = $SshUser
    Password              = $SshPassword
    ConfigDirectory       = $configDirFull
    OutputPath            = $outputFileFull
    ExtensionName         = $Extension
    AgentBaseDirectory    = $agentBaseDir
    AgentPort             = $AgentPort
    ConfigDirRel          = if ($agentPaths) { $agentPaths.ConfigDirRel } else { $null }
    OutputFileRel         = if ($agentPaths) { $agentPaths.OutputFileRel } else { $null }
    RestartAgent          = $RestartAgent
    StopAgent             = $StopAgent
    KeepAgentConnected    = $KeepAgentConnected
    DebugAgent            = $DebugAgent
    PauseBetweenCommands  = $PauseBetweenCommands
    RecreateExtension     = $RecreateExtension
    ExtensionPurpose      = $extensionPurposeAgent
    AgentCommandsOverride = $agentCommandsOverride
    AgentDebugOnly        = $agentDebugOnly
    Visible               = $Visible
}

$buildModeTitle = if ($UseAgentMode) { "режим агента" } else { "пакетный режим" }

Write-BuildModeHeader `
    -ModeTitle $buildModeTitle `
    -ExtensionName $Extension `
    -Version $version `
    -ConfigDirectory $configDirFull `
    -OutputPath $outputFileFull `
    -Database $database `
    -AgentPort $(if ($UseAgentMode) { $AgentPort } else { $null }) `
    -AgentUserBase $(if ($UseAgentMode) { $agentPaths.UserBase } else { $null })

try {
    $buildDuration = Invoke-CfeBuildCore -AgentMode:$UseAgentMode @buildParams
} catch {
    Write-Host ""
    Write-Host "Ошибка сборки: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
if ($agentDebugOnly) {
    Write-Host "Отладка команды агента завершена." -ForegroundColor Green
    Write-Host "Время: $(Format-BuildDuration -Duration $buildDuration)" -ForegroundColor Cyan
} else {
    Write-Host "Сборка завершена: $outputFileFull" -ForegroundColor Green
    Write-Host "Время сборки: $(Format-BuildDuration -Duration $buildDuration)" -ForegroundColor Cyan
    Copy-BuildArtifact -SourcePath $outputFileFull -TargetDirectory $CopyToDir
}

exit 0
