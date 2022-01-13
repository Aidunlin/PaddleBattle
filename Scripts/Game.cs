using Godot;
using Godot.Collections;

public class Game : Node
{
    public const string Version = "Dev Build";
    public const int MaxHealth = 3;
    public const int MoveSpeed = 600;

    [Export] public bool IsPlaying = false;
    [Export] public string MapName = "BigMap";
    [Export] public string Username = "";
    [Export] public long UserId = 0;

    public Dictionary<string, object> LoadOptionsFromFile()
    {
        Dictionary<string, object> options = new Dictionary<string, object>();
        options.Add("Vsync", OS.VsyncEnabled);
        options.Add("Fullscreen", OS.WindowFullscreen);
        options.Add("Map", MapName);
        File optionsFile = new File();

        if (optionsFile.FileExists("user://options.txt"))
        {
            optionsFile.Open("user://options.txt", File.ModeFlags.Read);
            Dictionary fileOptions = (Dictionary)JSON.Parse(optionsFile.GetLine()).Result;

            foreach (var item in options)
            {
                if (fileOptions.Contains(item.Key))
                {
                    options[item.Key] = fileOptions[item.Key];
                }
            }

            optionsFile.Close();
        }

        MapName = (string)options["Map"];
        return options;
    }

    public void SaveOptionsToFile(Dictionary<string, object> options)
    {
        File optionsFile = new File();
        optionsFile.Open("user://options.txt", File.ModeFlags.Write);
        optionsFile.StoreLine(JSON.Print(options));
        optionsFile.Close();
    }

    public void Reset()
    {
        IsPlaying = false;
    }
}
