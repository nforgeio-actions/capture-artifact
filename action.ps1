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
      
    $path   = Get-ActionInput "path"   $true
    $folder = Get-ActionInput "folder" $true
    $name   = Get-ActionInput "name"   $false

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
    #   3. Commit the change
    #   4. Pull any repo changes that somebody else just pushed 
    #   5. Push the repo

    Push-Cwd $naRoot | Out-Null

        git pull | Out-Null
        ThrowOnExitCode

        [System.IO.Directory]::CreateDirectory($targetFolder) | Out-Null
        [System.IO.File]::Copy($path, $targetPath, $true) | Out-Null

        git commit --all --message "capture artifact" | Out-Null
        ThrowOnExitCode

        git pull | Out-Null
        ThrowOnExitCode

        git push | Out-Null
        ThrowOnExitCode

    Pop-Cwd | Out-Null

    # Return the artifact URI

    Set-ActionOutput "artifact-uri" "https://github.com/nforgeio/artifacts/$folder/$targetName"
}
catch
{
    Write-ActionException $_
    exit 1
}
