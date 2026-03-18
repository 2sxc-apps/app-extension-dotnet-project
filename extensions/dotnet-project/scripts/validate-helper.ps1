param(
  [string]$Project = (Join-Path $PSScriptRoot '..\..\..\app.csproj')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectPath = (Resolve-Path $Project).Path

function Invoke-MsbuildCheck {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Title,

    [Parameter(Mandatory = $true)]
    [string[]]$Arguments
  )

  Write-Host ""
  Write-Host "== $Title =="
  Write-Host "dotnet $($Arguments -join ' ')"

  & dotnet @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "MSBuild check failed: $Title"
  }
}

Invoke-MsbuildCheck `
  -Title 'Property evaluation' `
  -Arguments @(
    'msbuild',
    $projectPath,
    '-nologo',
    '-getProperty:RunningInDnn',
    '-getProperty:RunningInOqtane',
    '-getProperty:TargetFramework',
    '-getProperty:PathBin'
  )

Invoke-MsbuildCheck `
  -Title 'Design-time compile' `
  -Arguments @(
    'msbuild',
    $projectPath,
    '-nologo',
    '-t:Compile',
    '-p:DesignTimeBuild=true',
    '-p:BuildingInsideVisualStudio=true',
    '-p:SkipCompilerExecution=true',
    '-v:minimal'
  )

Write-Host ""
Write-Host "Validation completed successfully."
