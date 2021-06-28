#Requires -Version 7.0 -RunAsAdministrator
#------------------------------------------------------------------------------
# FILE:         action.ps1
# CONTRIBUTOR:  Jeff Lill
# COPYRIGHT:    Copyright (c) 2005-2021 by neonFORGE LLC.  All rights reserved.
#
# The contents of this repository are for private use by neonFORGE, LLC. and may not be
# divulged or used for any purpose by other organizations or individuals without a
# formal written and signed agreement with neonFORGE, LLC.

# Verify that we're running on a properly configured neonFORGE GitHub runner 
# and import the deployment and action scripts from neonCLOUD.
      
# NOTE: This assumes that the required [$NC_ROOT/Powershell/*.ps1] files
#       in the current clone of the repo on the runner are up-to-date
#       enough to be able to obtain secrets and use GitHub Action functions.
#       If this is not the case, you'll have to manually pull the repo 
#       first on the runner.
      
$ncRoot = $env:NC_ROOT
$naRoot = $env:NA_ROOT
      
if ([System.String]::IsNullOrEmpty($ncRoot) -or ![System.IO.Directory]::Exists($ncRoot))
{
    throw "Runner Config: neonCLOUD repo is not present."
}
      
$ncPowershell = [System.IO.Path]::Combine($ncRoot, "Powershell")
      
Push-Location $ncPowershell | Out-Null
. ./includes.ps1
Pop-Location | Out-Null

try
{   
    # Fetch the inputs
      
    $path   = Get-ActionInput "path"          $true
    $folder = Get-ActionInput "target-folder" $true
    $name   = Get-ActionInput "target-name"   $false

    if (![System.IO.File]::Exists($path))
    {
        Write-ActionError "ERROR: File does not exist: $path"
        exit 1
    }

    # Generate the target file name, with a timestamp prefix

    if ([System.String]::IsNullOrEmpty($name))
    {
        $name = [System.IO.Path]::GetFileName($path)
    }

    $utcNow       = [System.DateTime]::UtcNow
    $timestamp    = $utcNow.ToString("yyyy-MM-ddThh_mm_ssZ")
    $targetFolder = [System.IO.Path]::Combine($naRoot, $folder)
    $targetName   = "$timestamp-$name"
    $targetPath   = [System.IO.Path]::Combine($targetFolder, $targetName)

    # Here's what we're going to do:
    #
    #   1. Pull the artifacts repo
    #   2. Copy the file to the repo, creating the folder if necessary
    #   3. Stage the changes 
    #   4. Commit the change
    #   5. Push the repo

    Push-Cwd $naRoot | Out-Null

        Invoke-CaptureStreams "git reset --quiet --hard" | Out-Null
        Invoke-CaptureStreams "git fetch --quiet" | Out-Null
        Invoke-CaptureStreams "git checkout --quiet master" | Out-Null    
        Invoke-CaptureStreams "git pull --quiet" | Out-Null

        [System.IO.Directory]::CreateDirectory($targetFolder) | Out-Null
        [System.IO.File]::Copy($path, $targetPath, $true) | Out-Null

        Invoke-CaptureStreams "git add --all" | Out-Null
        Invoke-CaptureStreams "git commit --quiet --all --message `"capture artifact`"" | Out-Null

        # $todo(jefflill):
        #
        # It's possible that another workflow has pushed changes to the
        # repo since we pulled above.  We'll detect this situation (once) and 
        # re-pull the repo before trying again.
        #
        # It would be nicer to abstract these repo operations into a couple 
        # Powershell functions.

        $result = Invoke-CaptureStreams "git push --quiet" -interleave -nocheck

        if ($result.exitcode -eq 1 -and $result.stderr.Contains("[rejected]") -and $result.stderr.Contains("(fetch first)"))
        {
            Invoke-CaptureStreams "git pull --quiet" | Out-Null
            Invoke-CaptureStreams "git push --quiet" | Out-Null
        }

    Pop-Cwd | Out-Null

    # Return the artifact URI

    Set-ActionOutput "uri" "https://github.com/nforgeio/artifacts/blob/master/$folder/$targetName"
}
catch
{
    Write-ActionException $_
    exit 1
}
