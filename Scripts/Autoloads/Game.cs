using Godot;
using Godot.Collections;

public class Game : Node
{
    public const string Version = "Dev Build";
    public const int MaxHealth = 3;
    public const int MoveSpeed = 600;

    [Export] public bool IsPlaying { get; set; } = false;

    public Dictionary<string, object> LoadSettingsFromFile()
    {
        Dictionary<string, object> settings = new Dictionary<string, object>();
        settings.Add("Vsync", OS.VsyncEnabled);
        settings.Add("Fullscreen", OS.WindowFullscreen);
        File settingsFile = new File();

        if (settingsFile.Open("user://settings.txt", File.ModeFlags.Read) == Error.Ok)
        {
            JSONParseResult result = JSON.Parse(settingsFile.GetLine());
            
            if (result.Error == Error.Ok && result.Result.GetType() == typeof(Dictionary))
            {
                Dictionary fileSettings = (Dictionary)result.Result;

                foreach (var item in settings)
                {
                    if (fileSettings.Contains(item.Key))
                    {
                        settings[item.Key] = fileSettings[item.Key];
                    }
                }
            }

            settingsFile.Close();
        }

        return settings;
    }

    public void SaveSettingsToFile(Dictionary<string, object> settings)
    {
        File settingsFile = new File();

        if (settingsFile.Open("user://settings.txt", File.ModeFlags.Write) == Error.Ok)
        {
            settingsFile.StoreLine(JSON.Print(settings));
            settingsFile.Close();
        }
    }

    public void Reset()
    {
        IsPlaying = false;
    }
}
