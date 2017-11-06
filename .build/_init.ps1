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
        & $NuGetPath install 'RedGate.Build' -OutputDirectory 'packages' -ExcludeVersion
        & $NuGetPath install 'Invoke-Build'  -OutputDirectory 'packages' -ExcludeVersion

        # Import the RedGate.Build module.
        Import-Module ".\packages\RedGate.Build\tools\RedGate.Build.psm1" -Force

        # Call the actual build script.
        & ".\packages\Invoke-Build\tools\Invoke-Build.ps1" -File '.\build.ps1' -Task $Task
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
