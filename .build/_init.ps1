# This file is a bootstrapper for the real build file. It's purpose is as follows:
#
# 1. Define some top-level functions (build, clean, rebuild) that can be used to kick off the build from the command-line.
# 2. Download nuget.exe.
# 3. Import the RedGate.Build module to make available some convenient build cmdlets.

$VerbosePreference = 'Continue'          # Want useful output in our build log files.
$ProgressPreference = 'SilentlyContinue' # Progress logging slows down TeamCity when downloading files with Invoke-WebRequest.
$ErrorActionPreference = 'Stop'          # Abort quickly on error.

function global:Build
{
    [CmdletBinding()]
    param(
        [string[]] $Task = @('Default')
    )

    Push-Location $PsScriptRoot -Verbose
    try
    {
        # Obtain nuget.exe
        $NuGetPath = '.\nuget.exe'
        if (-not (Test-Path $NuGetPath))
        {
            $NuGetUrl = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
            Write-Host "Downloading $NuGetUrl"
            Invoke-WebRequest $NuGetUrl -OutFile $NuGetPath
        }
        
        # Install the RedGate.Build module.
        $RedGateBuildVersion = '0.1.162'
        & $NuGetPath install 'RedGate.Build' `
            -Version $RedGateBuildVersion `
            -OutputDirectory 'packages' `
            -PackageSaveMode nuspec

        # Import the RedGate.Build module.
        Import-Module ".\packages\RedGate.Build.$RedGateBuildVersion\tools\RedGate.Build.psm1" -Force

        # Install Invoke-Build
        $InvokeBuildDir = Install-Package -Name 'Invoke-Build' -Version '2.12.2'

        # Call the actual build script.
        & "$InvokeBuildDir\tools\Invoke-Build.ps1" -File '.\build.ps1' -Task $Task
    }
    finally
    {
        Pop-Location
    }
}

function global:Clean 
{
    Build -Task Clean
}

function global:Rebuild
{
    Build -Task Rebuild
}

Write-Host 'This is the RedGate.ThirdParty.NodeJs repo. Here are the available commands:' -ForegroundColor Magenta
Write-Host "    Build [-Task <task-list>]" -ForegroundColor Green
Write-Host "    Clean" -ForegroundColor Green
Write-Host "    Rebuild" -ForegroundColor Green
