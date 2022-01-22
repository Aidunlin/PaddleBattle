using Godot;
using Godot.Collections;

public class MenuMain : VBoxContainer
{
    public Button PlayButton;
    public Button SettingsButton;
    public Button QuitButton;
    public Label VersionLabel;

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
