using Godot;
using Godot.Collections;

public class MenuDiscord : VBoxContainer
{
    private DiscordManager _discordManager;

    public Button Discord0Button { get; set; }
    public Button Discord1Button { get; set; }

    public override void _Ready()
    {
        _discordManager = GetNode<DiscordManager>("/root/DiscordManager");

        Discord0Button = GetNode<Button>("Discord0");
        Discord1Button = GetNode<Button>("Discord1");

        Discord0Button.Connect("pressed", this, "StartDiscord", new Array() { "0" });
        Discord1Button.Connect("pressed", this, "StartDiscord", new Array() { "1" });
    }

    public void StartDiscord(string instance)
    {
        _discordManager.Start(instance);
        Hide();
    }
}
