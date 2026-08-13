[CmdletBinding()]
param(
	[int] $Port = 34872
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$projectPath = Join-Path $repoRoot "default.project.json"

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

$rojo = Resolve-ProjectTool -Name "rojo"

Write-Output "[rojo serve] Live sync do codigo para o Studio (porta $Port)."
Write-Output "No Studio: aba Plugins -> Rojo -> Connect."
Write-Output "Enquanto isso rodar, salvar um arquivo em src/ atualiza o place aberto sem rebuild."
Write-Output "Ctrl+C encerra."
Write-Output ""

Push-Location $repoRoot
try {
	& $rojo serve $projectPath --port $Port
} finally {
	Pop-Location
}
