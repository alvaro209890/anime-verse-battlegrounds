[CmdletBinding()]
param(
	# Instala tambem em builds alternativos do Studio, se existirem.
	[switch] $AllStudioProfiles
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$projectPath = Join-Path $repoRoot "plugins\AvbDebug\plugin.project.json"

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

function Get-PluginDirectories {
	$dirs = @()
	$default = Join-Path $env:LOCALAPPDATA "Roblox\Plugins"
	$dirs += $default

	if ($AllStudioProfiles) {
		$versionsRoot = Join-Path $env:LOCALAPPDATA "Roblox\Versions"
		if (Test-Path -LiteralPath $versionsRoot) {
			foreach ($version in Get-ChildItem -LiteralPath $versionsRoot -Directory) {
				$candidate = Join-Path $version.FullName "Plugins"
				if (Test-Path -LiteralPath $candidate) {
					$dirs += $candidate
				}
			}
		}
	}

	return $dirs | Select-Object -Unique
}

$rojo = Resolve-ProjectTool -Name "rojo"

if (-not (Test-Path -LiteralPath $projectPath -PathType Leaf)) {
	throw "Projeto do plugin nao encontrado: $projectPath"
}

$targets = Get-PluginDirectories
$built = $false

foreach ($dir in $targets) {
	if (-not (Test-Path -LiteralPath $dir)) {
		New-Item -ItemType Directory -Path $dir -Force | Out-Null
		Write-Output "[plugin] Diretorio criado: $dir"
	}

	$output = Join-Path $dir "AvbDebug.rbxm"
	Write-Output "[plugin] Gerando $output..."
	& $rojo build $projectPath --output $output
	if ($LASTEXITCODE -ne 0) {
		throw "rojo build falhou com exit code $LASTEXITCODE"
	}

	$artifact = Get-Item -LiteralPath $output
	if ($artifact.Length -le 0) {
		throw "Artefato vazio: $output"
	}
	Write-Output "[plugin] OK  $($artifact.FullName)  ($($artifact.Length) bytes)"
	$built = $true
}

if (-not $built) {
	throw "Nenhum diretorio de plugins encontrado."
}

Write-Output ""
Write-Output "Proximos passos:"
Write-Output "  1. O Roblox Studio recarrega plugins sozinho; se ja estava aberto, feche e abra o place."
Write-Output "  2. Autorize o plugin quando o Studio pedir (o plugin usa HttpService em 127.0.0.1)."
Write-Output "  3. Suba a ponte:  lune run scripts/debug-bridge.luau"
Write-Output "  4. Teste:         lune run scripts/avb-debug.luau ping"
