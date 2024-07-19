[CmdletBinding(SupportsShouldProcess=$True)]
Param()

if (-not $env:NUGET_SOURCE) 
{
    throw "Environment variables NUGET_SOURCE is not set."
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

$nugetVersions = Find-Package -AllVersions -AllowPrereleaseVersions -Source $env:NUGET_SOURCE ALC.Analyzer.Dlls `
    | Select-Object -ExpandProperty Version

$newVsixData = $vsixData | Where-Object { $nugetVersions -notcontains $_.Version }

if ($newVsixData.Length -eq 0)
{
    Write-Host "No new vsix versions found. Aborting."
    return;
}

$newVsixData | ConvertTo-Json -Compress