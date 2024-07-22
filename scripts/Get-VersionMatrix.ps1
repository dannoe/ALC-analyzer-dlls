[CmdletBinding(SupportsShouldProcess=$True)]
Param(
    [string] $ForceVersion
)

if (-not $env:NUGET_SOURCE) 
{
    Write-Host "::error title=Environment variables not set::Environment variable NUGET_SOURCE is not set."
    throw "Environment variable NUGET_SOURCE is not set."
}

$webRequestParams = @{
    Method = 'POST'
    UseBasicParsing = $True
    Uri = 'https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery?api-version=3.0-preview.1'
    Body = '{"filters":[{"criteria":[{"filterType":8,"value":"Microsoft.VisualStudio.Code"},{"filterType":12,"value":"4096"},{"filterType":7,"value":"ms-dynamics-smb.al"}],"pageNumber":1,"pageSize":50,"sortBy":0,"sortOrder":0}],"assetTypes":["Microsoft.VisualStudio.Services.VSIXPackage"],"flags":147}'
    ContentType = 'application/json'
}

$listing = Invoke-WebRequest @webRequestParams
    | ConvertFrom-Json

$nugetVersions = Find-Package -AllVersions -AllowPrereleaseVersions -Source $env:NUGET_SOURCE Unofficial.Microsoft.Dynamics.Nav.CodeAnalysis `
    | Select-Object -ExpandProperty Version | % { $_.Split('-')[0] }

if ($ForceVersion)
{
    Write-Host "::notice title=Force version::Running with force version: $ForceVersion"
    $filterVsix = {
        param([Version]$version)
        $version -eq $ForceVersion
    }
    $filterNuget = { $true }
} else {
    $filterVsix = {
        param([Version]$version)
        $version -ge [Version]"14.0.1002061"
    }
    $filterNuget = { 
        param([Version]$version) 
        $nugetVersions -notcontains $version 
        }
}

$vsixData = $listing.results.extensions.versions `
    | Where-Object properties -ne $null `
    | Where-Object { & $filterVsix $_.Version } `
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

if ($vsixData.Length -eq 0)
{
    Write-Host "::error title=Error::No vsix versions found. Make sure the version string is correct"
    return;
}

$vsixData = $vsixData | Where-Object { & $filterNuget $_.Version }

if ($vsixData.Length -eq 0)
{
    Write-Host "::notice title=Notice::No new vsix versions found. Aborting."
    return;
}

$vsixData | ConvertTo-Json -Compress