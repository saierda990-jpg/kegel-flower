namespace KikuKegel.Windows;

internal static class StoragePaths
{
    public static string AppDataDirectory
    {
        get
        {
            var directory = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                "KikuKegel"
            );
            Directory.CreateDirectory(directory);
            return directory;
        }
    }

    public static string File(string name) => Path.Combine(AppDataDirectory, name);
}
