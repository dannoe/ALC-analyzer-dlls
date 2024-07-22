using System.Diagnostics;
using System.Diagnostics.CodeAnalysis;
using System.Reflection;
using System.Runtime.Versioning;
using System.Text.Json;
using Mono.Cecil;
using System.Xml.Linq;

class Program
{

    static void Main(string[] args)
    {
        var assemblyPath = args[0];
        var nuspecPath = args[1];
        var version = new Version(args[2]);
        
        var ignoredDependencies = GetIgnoredDependencies();

        if (!File.Exists(assemblyPath))
        {
            Console.WriteLine("Assembly file not found.");
            return;
        }

        var nugetAssemblyDefinition = GetNuspecAssemblyDefinition(assemblyPath, ignoredDependencies);
        GenerateNuspecFile(nugetAssemblyDefinition, nuspecPath, assemblyPath, version); 
    }

    private static List<string>? GetIgnoredDependencies()
    {
        var appPath = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
        var filePath = Path.Combine(appPath ?? string.Empty, "ignoredDependencies.json");
        if (!File.Exists(filePath))
        {
            return [];
        }
        
        var ignoredDependenciesJson = File.ReadAllText(filePath);
        return JsonSerializer.Deserialize<List<string>>(ignoredDependenciesJson);
    }

    static NuspecAssemblyDefinition GetNuspecAssemblyDefinition(string assemblyPath, List<string>? ignoredDependencies)
    {
        var dependencies = new List<(string Name, Version Version)>();
        var assembly = AssemblyDefinition.ReadAssembly(assemblyPath);

        var netstandardFound = string.Empty;

        foreach (var reference in assembly.MainModule.AssemblyReferences)
        {
            if (!reference.FullName.Contains("netstandard"))
            {
                if (reference.Name.StartsWith("Microsoft.Dynamics") && (ignoredDependencies == null || !ignoredDependencies.Contains(reference.Name)))
                {
                    dependencies.Add(($"Unofficial.{reference.Name}", reference.Version));    
                }
            }
            else
            {
                // some assemblies do not have a TargetFrameworkAttribute,
                // we use this really dirty hack :( to try to determine the target framework:
                netstandardFound = $"{reference.Name}{reference.Version.Major}.{reference.Version.Minor}"; 
            }
        }

        if (TryGetTargetFramework(assembly, out var targetFramework))
        {
            targetFramework = MapToCanonicalForm(targetFramework);
        }
        else
        {
            if (netstandardFound != string.Empty)
            {
                targetFramework = netstandardFound;
            }
            else
            {
                throw new InvalidOperationException(
                    $"Could not determine the target framework for assembly {assembly.FullName}");
            }
        }

        return new NuspecAssemblyDefinition(assembly.Name.Name, targetFramework, dependencies, assembly.Name.Version);
    }

    private static string MapToCanonicalForm(string targetFramework)
    {
        return targetFramework.ToLower() switch
        {
            ".net standard 2.0" => "netstandard2.0",
            ".net standard 2.1" => "netstandard2.1",
            ".net 8.0" => "net8.0",
            _ => throw new ArgumentOutOfRangeException($"No canonical mapping for {targetFramework} found.")
        };
    }

    private static bool TryGetTargetFramework(AssemblyDefinition assembly, [NotNullWhen(true)]out string? targetFramework)
    {
        var targetFrameworkAttribute = assembly.CustomAttributes.FirstOrDefault(attribute => attribute.AttributeType.Name == nameof(TargetFrameworkAttribute));

        if (targetFrameworkAttribute == null)
        {
            targetFramework = string.Empty;
            return false;
        }

        var customAttributeProperty = targetFrameworkAttribute.Properties.FirstOrDefault();
        targetFramework = customAttributeProperty.Argument.Value as string;
        if (targetFramework == null)
        {
            targetFramework = string.Empty;
            return false;
        }

        return true;
    }

    static void GenerateNuspecFile(NuspecAssemblyDefinition assemblyDefinition, string nuspecPath, string assemblyPath,
        Version version)
    {
        var nuspec = new XElement("package",
            new XElement("metadata",
                new XElement("id", assemblyDefinition.UnofficialPackageId),
                new XElement("version", version),
                new XElement("title", $"Unofficial package for the {assemblyDefinition.Name} assembly"),
                new XElement("authors", "Microsoft"),
                new XElement("requireLicenseAcceptance", "false"),
				new XElement("license", 
					new XAttribute("type", "file"),
					"LICENSE.md"),
                new XElement("readme", "README.md"),
                new XElement("projectUrl", "https://github.com/dannoe/ALC-analyzer-dlls")
                new XElement("description", $"Unofficial package for the {assemblyDefinition.Name} assembly"),
                new XElement("tags", "AL BusinessCentral BC Compiler"),
                new XElement("dependencies",
                    new XElement("group", new XAttribute("targetFramework", assemblyDefinition.TargetFramework),
                        assemblyDefinition.Dependencies.Select(d => 
                            new XElement("dependency",
                                new XAttribute("id", d.Name), // Taking only the name part of the assembly
                                new XAttribute("version", version) // Adjust version accordingly
                            )
                        )
                    )
                )
            ),
            new XElement("files",
                new XElement("file",
                    new XAttribute("src", "LICENSE.md"),
                    new XAttribute("target", "")
                ),
                new XElement("file",
                    new XAttribute("src", "README.md"),
                    new XAttribute("target", "")
                ),
                new XElement("file",
                    new XAttribute("src", assemblyPath),
                    new XAttribute("target", $"lib\\{assemblyDefinition.TargetFramework}")) 
            )
        );

        nuspec.Save(nuspecPath);
    }
}

internal record NuspecAssemblyDefinition(string Name, string TargetFramework, List<(string Name, Version Version)> Dependencies, Version Version)
{
    public string UnofficialPackageId => $"Unofficial.{Name}";
}
