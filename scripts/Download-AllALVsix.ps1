[CmdletBinding(SupportsShouldProcess=$True)]
Param()

$webRequestParams = @{
    Method = 'POST'
    UseBasicParsing = $True
    Uri = 'https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery?api-version=3.0-preview.1'
    Body = '{"filters":[{"criteria":[{"filterType":8,"value":"Microsoft.VisualStudio.Code"},{"filterType":12,"value":"4096"},{"filterType":7,"value":"ms-dynamics-smb.al"}],"pageNumber":1,"pageSize":50,"sortBy":0,"sortOrder":0}],"assetTypes":["Microsoft.VisualStudio.Services.VSIXPackage"],"flags":147}'
    ContentType = 'application/json'
}

$listing = Invoke-WebRequest @webRequestParams
    | ConvertFrom-Json

$vsixData = $listing.results.extensions.versions `
    | Where-Object properties -ne $null `
    | Where-Object { [Version]$_.Version -ge [Version]"10.0.0" } `
    | ForEach-object { 
        $extensionProperties = @{
            Version = $_.Version
            Prerelease = $_.properties.key -contains 'Microsoft.VisualStudio.Code.PreRelease'
            PackageUrl  = $_ | Select-Object -ExpandProperty files `
                                | Where-Object { $_.assetType -eq 'Microsoft.VisualStudio.Services.VSIXPackage' } `
                                | Select-Object -ExpandProperty source
        }
        New-Object psobject -Property $extensionProperties
    }

$nugetVersions = Find-Package -AllVersions -AllowPrereleaseVersions -Source $nugetSource ALC.Dlls `
    | Select-Object -ExpandProperty Version

foreach ($vsix in $vsixData)
{
    if ($nugetVersions -notcontains $vsix.Version)
    {
        if ($WhatIfPreference) {
            Write-Host .\Push-ALVsixAsNuget.ps1 -Version $vsix.Version -Prerelease $vsix.Prerelease -VsixPackageUrl $vsix.PackageUrl
        } 
        else {
            .\Push-ALVsixAsNuget.ps1 -Version $vsix.Version -Prerelease $vsix.Prerelease -VsixPackageUrl $vsix.PackageUrl
        }
    }
}
