using Godot;
using Godot.Collections;

public class Game : Node
{
    public const string Version = "Dev Build";
    public const int MaxHealth = 3;
    public const int MoveSpeed = 600;

    [Export] public bool IsPlaying { get; set; } = false;

    public override void _Ready()
    {
        LoadSettings();
    }

    public void LoadSettings()
    {
        var config = new ConfigFile();

        if (config.Load("user://settings.cfg") == Error.Ok)
        {
            OS.VsyncEnabled = (bool)config.GetValue("Settings", "Vsync", OS.VsyncEnabled);
            OS.WindowFullscreen = (bool)config.GetValue("Settings", "Fullscreen", OS.WindowFullscreen);
        }
    }

    public void SaveSettings()
    {
        var config = new ConfigFile();
        config.SetValue("Settings", "Vsync", OS.VsyncEnabled);
        config.SetValue("Settings", "Fullscreen", OS.WindowFullscreen);
        config.Save("user://settings.cfg");
    }

    public void Reset()
    {
        IsPlaying = false;
    }
}
