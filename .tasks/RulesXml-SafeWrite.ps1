# Safe write for large KD exchange-rules XML.
# Write to temp -> validate -> atomic replace. Never truncate target mid-write.
# ASCII-only source for Windows PowerShell 5.1.

# Do not name this U — many rules scripts define their own U([int[]]).
function ConvertFrom-RulesXmlUEscape([string]$s) {
	return [regex]::Replace($s, '\\u([0-9A-Fa-f]{4})', {
		param($m)
		return [string][char][Convert]::ToInt32($m.Groups[1].Value, 16)
	})
}

function Test-RulesXmlIntegrity {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Path,
		[long]$MinBytes = 0,
		[long]$MinRatioOfOriginal = 0, # 0..100; 0 = skip
		[long]$OriginalBytes = 0
	)
	if (-not (Test-Path -LiteralPath $Path)) {
		throw "Rules XML not found: $Path"
	}
	$item = Get-Item -LiteralPath $Path
	if ($item.Length -le 0) {
		throw "Rules XML is empty: $Path"
	}
	if ($MinBytes -gt 0 -and $item.Length -lt $MinBytes) {
		throw ("Rules XML too small: {0} bytes < min {1}" -f $item.Length, $MinBytes)
	}
	if ($MinRatioOfOriginal -gt 0 -and $OriginalBytes -gt 0) {
		$ratio = [math]::Floor(($item.Length * 100.0) / $OriginalBytes)
		if ($ratio -lt $MinRatioOfOriginal) {
			throw ("Rules XML shrunk too much: {0}% of original ({1} -> {2}), min {3}%" -f `
				$ratio, $OriginalBytes, $item.Length, $MinRatioOfOriginal)
		}
	}

	$utf8 = New-Object System.Text.UTF8Encoding $false
	# Read only tail for end-tag check (large files)
	$fs = [IO.File]::OpenRead($Path)
	try {
		$tailLen = [Math]::Min(4096, $fs.Length)
		$fs.Seek(-$tailLen, [IO.SeekOrigin]::End) | Out-Null
		$buf = New-Object byte[] $tailLen
		[void]$fs.Read($buf, 0, $tailLen)
	}
	finally { $fs.Close() }
	$tail = $utf8.GetString($buf)
	$close = ConvertFrom-RulesXmlUEscape('\u003c\u002f\u041f\u0440\u0430\u0432\u0438\u043b\u0430\u041e\u0431\u043c\u0435\u043d\u0430\u003e')
	if (-not $tail.TrimEnd().EndsWith($close)) {
		$preview = $tail.Substring([Math]::Max(0, $tail.Length - 120)) -replace '\r?\n', '\n'
		throw ("Rules XML bad ending (expected </ПравилаОбмена>). Tail: {0}" -f $preview)
	}
	# truncated tag fingerprints near EOF
	$broken = ConvertFrom-RulesXmlUEscape('\u003c\u041f\u0440\u0438\u0435\u043c\u043d') # <Приемн
	if ($tail.TrimEnd().EndsWith($broken) -or $tail -match [regex]::Escape($broken) + '\s*$') {
		throw "Rules XML looks truncated (broken Приемник tag at EOF)"
	}
	return $true
}

function Save-RulesXmlAtomic {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Path,
		[Parameter(Mandatory = $true)]
		[string]$Content,
		[long]$MinRatioOfOriginal = 50,
		[switch]$SkipBackup
	)
	$utf8 = New-Object System.Text.UTF8Encoding $false
	$dir = Split-Path -Parent $Path
	if ([string]::IsNullOrWhiteSpace($dir)) { $dir = (Get-Location).Path }
	$name = Split-Path -Leaf $Path
	$originalBytes = 0
	if (Test-Path -LiteralPath $Path) {
		$originalBytes = (Get-Item -LiteralPath $Path).Length
		if (-not $SkipBackup) {
			$bak = $Path + ".bak-before-safe-write"
			if (-not (Test-Path -LiteralPath $bak)) {
				Copy-Item -LiteralPath $Path -Destination $bak -Force
			}
		}
	}

	$tmp = Join-Path $dir ("{0}.tmp-{1}-{2}" -f $name, $PID, [DateTime]::UtcNow.Ticks)
	$replaceBak = Join-Path $dir ("{0}.bak-replace-{1}" -f $name, [DateTime]::UtcNow.Ticks)
	try {
		[IO.File]::WriteAllText($tmp, $Content, $utf8)
		Test-RulesXmlIntegrity -Path $tmp -MinRatioOfOriginal $MinRatioOfOriginal -OriginalBytes $originalBytes | Out-Null
		if (Test-Path -LiteralPath $Path) {
			[IO.File]::Replace($tmp, $Path, $replaceBak)
			Remove-Item -LiteralPath $replaceBak -Force -ErrorAction SilentlyContinue
		}
		else {
			Move-Item -LiteralPath $tmp -Destination $Path -Force
		}
		# tmp consumed by Replace/Move
		$tmp = $null
		Test-RulesXmlIntegrity -Path $Path -MinRatioOfOriginal $MinRatioOfOriginal -OriginalBytes $originalBytes | Out-Null
		Write-Host ("SafeWrite OK: {0} size={1}" -f $Path, (Get-Item -LiteralPath $Path).Length)
	}
	catch {
		if ($tmp -and (Test-Path -LiteralPath $tmp)) {
			Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
		}
		if (Test-Path -LiteralPath $replaceBak) {
			Remove-Item -LiteralPath $replaceBak -Force -ErrorAction SilentlyContinue
		}
		throw
	}
}

# Dot-source export marker
$script:RulesXmlSafeWriteLoaded = $true
