using Godot;
using Godot.Collections;

public class MenuSettings : VBoxContainer
{
    private Game _game;

    public CheckButton VsyncButton { get; set; }
    public CheckButton FullscreenButton { get; set; }
    public Button DoneButton { get; set; }

    public override void _Ready()
    {
        _game = GetNode<Game>("/root/Game");

        VsyncButton = GetNode<CheckButton>("Vsync");
        FullscreenButton = GetNode<CheckButton>("Fullscreen");
        DoneButton = GetNode<Button>("Done");

        VsyncButton.Connect("pressed", this, "ToggleVsync");
        FullscreenButton.Connect("pressed", this, "ToggleFullscreen");

        VsyncButton.Pressed = OS.VsyncEnabled;
        FullscreenButton.Pressed = OS.WindowFullscreen;
    }
    
    public void ToggleVsync()
    {
        OS.VsyncEnabled = !OS.VsyncEnabled;
    }

    public void ToggleFullscreen()
    {
        OS.WindowFullscreen = !OS.WindowFullscreen;
    }
}
