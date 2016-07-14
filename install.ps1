$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

# Establish the path of the self-extracting archive file and the output dir.
$script:ArchivePath = ("$PSScriptRoot\dist\nodejs-sfx.exe",
                        "$PSScriptRoot\nodejs-sfx.exe") | Where-Object { Test-Path $_ } | Resolve-Path
$PropsPath = ("$PSScriptRoot\RedGate.ThirdParty.NodeJs.props",
                "$PSScriptRoot\..\build\RedGate.ThirdParty.NodeJs.props") | Where-Object { Test-Path $_ } | Resolve-Path
$NodeJsVersion = [string] ([xml](Get-Content $PropsPath)).Project.PropertyGroup.NodeJsVersion
$script:OutputDir = "$env:SystemDrive\Tools\NodeJs\$NodeJsVersion\" # Must include the trailing slash.
Write-Verbose "Self-extracting archive path: $ArchivePath"
Write-Verbose "Output dir: $OutputDir"

# Name of the global mutex used to lock access to the output dir.
$MutexName = "Global\NodeJsExtractDir-$($OutputDir.ToLowerInvariant() -replace '[^a-z0-9]', '-')"

# Create the mutex.
$SecurityIdentifier = New-Object -TypeName 'System.Security.Principal.SecurityIdentifier' -ArgumentList ([System.Security.Principal.WellKnownSidType]::WorldSid, $Null)
$AllowEveryoneRule = New-Object -TypeName 'System.Security.AccessControl.MutexAccessRule' -ArgumentList ($SecurityIdentifier, [System.Security.AccessControl.MutexRights]::FullControl, [System.Security.AccessControl.AccessControlType]::Allow)
$MutexSecurity = New-Object -TypeName 'System.Security.AccessControl.MutexSecurity'
$MutexSecurity.AddAccessRule($AllowEveryoneRule)
[bool] $CreatedNew = $False
$Mutex = New-Object -TypeName 'System.Threading.Mutex' -ArgumentList ($False, $MutexName, [ref] $CreatedNew, $MutexSecurity)

try {
    # Acquire the mutex.
    Write-Verbose "Acquiring mutex $MutexName"
    try {
        $Null = $Mutex.WaitOne()
    } catch [System.Threading.AbandonedMutexException] {
        # Raised if another process abandoned the mutex, in which case we now own it.
    }

    try {
        # Only proceed if the archive hasn't previously been extracted.
        $MarkerFilePath = "$OutputDir.extracted"
        if (-not (Test-Path $MarkerFilePath)) {

            # Extract nodejs from the self-extracting archive file.
            Write-Verbose "Extracting nodejs to $OutputDir"
            & $ArchivePath -y -o "$OutputDir"

            # Make sure it completed successfully.
            if ($LastExitCode -ne 0) {
                # If it didn't complete successfully, the output folder may be corrupted.
                ## Make a best effort to remove it.
                try {
                    if (Test-Path $OutputDir) {
                        Remove-Item $Output -Force -Recurse
                    }
                } catch {
                    Write-Warning "Failed to clean up $OutputDir"
                }
                throw "nodejs-sfx.exe terminated with exit code $LastExitCode"
            }

            # And finally write the marker file to indicate that the archive has been successfully extracted.
            [System.DateTime]::UtcNow.ToString('u') | Out-File $MarkerFilePath 
        
        } else {
            Write-Verbose "nodejs has already been previously extracted to $OutputDir"
        }

        # Write the output dir to the pipeline.
        Write-Output $OutputDir

    } finally {
        # Always release the mutex.
        Write-Verbose "Releasing mutex $MutexName"
        $Mutex.ReleaseMutex()
    }
} finally {
    # Always dispose of the mutex object.
    $Mutex.Dispose()
}
