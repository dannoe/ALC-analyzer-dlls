param (
    [switch] $Prerelease,
    [Parameter(Mandatory)] 
    [string] $Version,
    [Parameter(Mandatory)] 
    [string] $VsixPackageUrl
)

function New-TemporaryDirectory {
    $parent = [System.IO.Path]::GetTempPath()
    do {
        $name = [System.IO.Path]::GetRandomFileName()
        $item = New-Item -Path $parent -Name $name -ItemType Directory -ErrorAction SilentlyContinue
    } while (-not $item)
    return $item.FullName
}

$tempFile = New-TemporaryFile
$tempFolder = New-TemporaryDirectory

Invoke-WebRequest $VsixPackageUrl -OutFile $tempFile
Expand-Archive -Path $tempFile -DestinationPath $tempFolder

Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue

Write-Verbose $tempFolder

$assemblies = @"
[
    { "name": "Microsoft.Dynamics.Nav.AL.Common", "path": "bin/Analyzers/" },
    { "name": "Microsoft.Dynamics.Nav.Analyzers.Common", "path": "bin/Analyzers/" },
    { "name": "Microsoft.Dynamics.Nav.CodeAnalysis", "path": "bin/Analyzers/" },
    { "name": "Microsoft.Dynamics.Nav.CodeAnalysis.Workspaces", "path": "bin/Analyzers/" },
    { "name": "Microsoft.Dynamics.Nav.AppSourceCop", "path": "bin/Analyzers/" },
	{ "name": "Microsoft.Dynamics.Nav.UICop", "path": "bin/Analyzers/" },
    { "name": "Microsoft.Dynamics.Nav.CodeCop", "path": "bin/Analyzers/" },
    { "name": "Microsoft.Dynamics.Nav.PerTenantExtensionCop", "path": "bin/Analyzers/" },
]
"@ | ConvertFrom-Json

foreach($assembly in $assemblies) 
{
    $sourceFile = Join-Path $tempfolder extension $assembly.path "$($assembly.name).dll"
    $targetFile = "$($assembly.name).nuspec"

    dotnet run --project "../src/GenerateNuspecWithDependencies/" -- "$sourceFile" "$targetFile" $Version
    if ($LASTEXITCODE -eq 0)
    {
        Write-Host "Success!"
        # define the placeholders and their values
        if ($prerelease) {
            $suffix = "prerelease"
        } else 
        {
            $suffix = ""
        }

        nuget pack $targetFile -OutputDirectory "../artifacts/" -Version $version -Suffix $suffix
    } else 
    {
        Write-Error "Error on generating the nuspec file for $($assembly.Name)"
    }
}

Remove-Item -Path $tempFolder -Force -Recurse -ErrorAction SilentlyContinue