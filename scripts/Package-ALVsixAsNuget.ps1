param (
    [Parameter(Mandatory)] 
    [switch] $Prerelease = $true,
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

$analyzerAssembliesToCopy = @(
    "Microsoft.Dynamics.Nav.AL.Common.dll",
    "Microsoft.Dynamics.Nav.CodeAnalysis.dll",
    "Microsoft.Dynamics.Nav.CodeAnalysis.Workspaces.dll",
    "Microsoft.Dynamics.Nav.CodeCop.dll",
    "Microsoft.Dynamics.Nav.UICop.dll"
)

New-Item -Type Directory ..\src\ALC.Analyzer.Dlls\libs -Force

Get-ChildItem -Path (Join-Path $tempFolder \extension\bin\Analyzers) -Filter "*.dll" `
    | Where-Object { $analyzerAssembliesToCopy -contains $_.Name } `
    | ForEach-Object { 
        Write-Verbose $_.FullName
        Copy-Item -Path $_.FullName -Destination ..\src\ALC.Analyzer.Dlls\libs\ 
        }

$compilerAssembliesToCopy = @(
    "Microsoft.Dynamics.Nav.EditorServices.Protocol.dll"
)

Get-ChildItem -Path (Join-Path $tempFolder \extension\bin\win32) -Filter "*.dll" `
    | Where-Object { $compilerAssembliesToCopy -contains $_.Name } `
    | ForEach-Object { 
        Write-Verbose $_.FullName
        Copy-Item -Path $_.FullName -Destination ..\src\ALC.Analyzer.Dlls\libs\ 
    }

$VersionSuffix = ""
if ($Prerelease)
{
	$VersionSuffix = "prerelease"
}

dotnet pack ..\src\ALC.Analyzer.Dlls\ -p:PackageVersion=$($Version) --version-suffix $VersionSuffix --output ..\artifacts

Remove-Item -Path $tempFolder -Force -ErrorAction SilentlyContinue -Recurse