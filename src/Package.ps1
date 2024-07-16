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
    { "name": "Microsoft.Dynamics.Nav.AL.Common", "targetFramework": "netstandard2.0", "path": "bin/Analyzers/" },
    { "name": "Microsoft.Dynamics.Nav.Analyzers.Common", "targetFramework": "netstandard2.0", "path": "bin/Analyzers/" },
    { "name": "Microsoft.Dynamics.Nav.CodeAnalysis", "targetFramework": "netstandard2.0", "path": "bin/Analyzers/" },
    { "name": "Microsoft.Dynamics.Nav.CodeAnalysis.Workspaces", "targetFramework": "netstandard2.0", "path": "bin/Analyzers/" },
    { "name": "Microsoft.Dynamics.Nav.AppSourceCop", "targetFramework": "netstandard2.0", "path": "bin/Analyzers/" },
	{ "name": "Microsoft.Dynamics.Nav.UICop", "targetFramework": "netstandard2.0", "path": "bin/Analyzers/" },
    { "name": "Microsoft.Dynamics.Nav.CodeCop", "targetFramework": "netstandard2.0", "path": "bin/Analyzers/" },
    { "name": "Microsoft.Dynamics.Nav.PerTenantExtensionCop", "targetFramework": "netstandard2.0", "path": "bin/Analyzers/" },
    { "name": "Microsoft.Dynamics.Nav.EditorServices.Protocol", "targetFramework": "net8.0", "path": "bin/win32/" },
]
"@ | ConvertFrom-Json

$templatepath = "template.nuspec"

foreach($assembly in $assemblies) 
{
    # define the placeholders and their values
    $id = "Unofficial.$($assembly.name)"
    $description = "Unofficial package for the $($assembly.name) assembly"
    $file = $assemblyname
    $targetFramework = $assembly.targetFramework
    $sourceFile = Join-path $tempfolder extension $assembly.path "$($assembly.name).dll"
    Write-Host $sourceFile
    $targetPath = Join-path "lib" $targetFramework
    Write-Host $targetPath
    if ($prerelease) {
        $suffix = "prerelease"
    } else 
    {
        $suffix = ""
    }

    # Read the template content
    $templateContent = Get-Content -Path $templatePath

    # Replace the placeholders with the actual values
    $templateContent = $templateContent -replace "{{ id }}", $id
    $templateContent = $templateContent -replace "{{ description }}", $description
    $templateContent = $templateContent -replace "{{ file }}", $file
    $templateContent = $templateContent -replace "{{ targetFramework }}", $targetFramework
    $templateContent = $templateContent -replace "{{ sourceFile }}", $sourceFile
    $templateContent = $templateContent -replace "{{ targetPath }}", $targetPath

    # Define the output file path
    $outputPath = "$id.nuspec"

    # Write the updated content to the output file
    $templateContent | Set-Content -Path $outputPath

    nuget pack $outputPath -OutputDirectory "..\artifacts\" -Version $version -Suffix $suffix
}

Remove-Item -Path $tempFolder -Force -Recurse -ErrorAction SilentlyContinue