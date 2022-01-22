using Godot;
using Godot.Collections;

public class MenuMain : VBoxContainer
{
    public Button PlayButton { get; set; }
    public Button SettingsButton { get; set; }
    public Button QuitButton { get; set; }
    public Label VersionLabel { get; set; }

    public override void _Ready()
    {
        PlayButton = GetNode<Button>("Play");
        SettingsButton = GetNode<Button>("Settings");
        QuitButton = GetNode<Button>("Quit");
        VersionLabel = GetNode<Label>("Version");

        QuitButton.Connect("pressed", GetTree(), "quit");
        VersionLabel.Text = Game.Version;
    }
}
