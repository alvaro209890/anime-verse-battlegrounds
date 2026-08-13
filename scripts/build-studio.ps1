[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$projectPath = Join-Path $repoRoot "default.project.json"
$packagesPath = Join-Path $repoRoot "Packages"
$artifactPath = Join-Path $repoRoot "anime-verse-battlegrounds.rbxl"

function Resolve-ProjectTool {
	param([Parameter(Mandatory = $true)][string] $Name)

	$command = Get-Command $Name -ErrorAction SilentlyContinue
	if ($null -ne $command) {
		return $command.Source
	}

	$aftmanPath = Join-Path $env:USERPROFILE ".aftman\bin\$Name.exe"
	if (Test-Path -LiteralPath $aftmanPath -PathType Leaf) {
		return $aftmanPath
	}

	throw "Ferramenta '$Name' nao encontrada. Rode 'aftman install' e tente novamente."
}

function Invoke-ProjectTool {
	param(
		[Parameter(Mandatory = $true)][string] $Tool,
		[Parameter(Mandatory = $true)][string[]] $Arguments
	)

	& $Tool @Arguments
	if ($LASTEXITCODE -ne 0) {
		throw "Comando '$Tool $($Arguments -join ' ')' falhou com exit code $LASTEXITCODE."
	}
}

$wally = Resolve-ProjectTool -Name "wally"
$rojo = Resolve-ProjectTool -Name "rojo"

Push-Location $repoRoot
try {
	Write-Output "[Studio build] Instalando dependencias Wally..."
	Invoke-ProjectTool -Tool $wally -Arguments @("install")

	if (Test-Path -LiteralPath $packagesPath) {
		if (-not (Get-Item -LiteralPath $packagesPath).PSIsContainer) {
			throw "O caminho Packages existe, mas nao e um diretorio: $packagesPath"
		}
	} else {
		New-Item -ItemType Directory -Path $packagesPath | Out-Null
		Write-Output "[Studio build] Diretorio Packages criado."
	}

	$buildStartedAt = [DateTime]::UtcNow
	Write-Output "[Studio build] Gerando $artifactPath..."
	Invoke-ProjectTool -Tool $rojo -Arguments @("build", $projectPath, "--output", $artifactPath)

	if (-not (Test-Path -LiteralPath $artifactPath -PathType Leaf)) {
		throw "Rojo terminou sem gerar o artefato esperado: $artifactPath"
	}

	$artifact = Get-Item -LiteralPath $artifactPath
	if ($artifact.Length -le 0) {
		throw "O artefato gerado esta vazio: $artifactPath"
	}
	if ($artifact.LastWriteTimeUtc -lt $buildStartedAt.AddSeconds(-2)) {
		throw "O artefato nao foi atualizado por este build: $artifactPath"
	}

	$hash = Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256
	Write-Output "[Studio build] OK"
	Write-Output "Arquivo: $($artifact.FullName)"
	Write-Output "Tamanho: $($artifact.Length) bytes"
	Write-Output "Atualizado: $($artifact.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss.fff zzz'))"
	Write-Output "SHA256: $($hash.Hash)"
	Write-Output "Feche o place antigo no Studio, reabra este arquivo e so entao use Play."
} finally {
	Pop-Location
}
