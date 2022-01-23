using Godot;
using Godot.Collections;

public class MenuManager : HBoxContainer
{
    private Game _game;
    private DiscordManager _discordManager;

    [Signal] public delegate void MapSwitched();
    [Signal] public delegate void PlayRequested();
    [Signal] public delegate void EndRequested();
    [Signal] public delegate void LeaveRequested();

    public MenuDiscord DiscordMenu { get; set; }
    public MenuMain MainMenu { get; set; }
    public MenuMatch MatchMenu { get; set; }
    public MenuSettings SettingsMenu { get; set; }
    public MenuOptions OptionsMenu { get; set; }

    public MenuLeftSide LeftSideMenu { get; set; }
    public MenuRightSide RightSideMenu { get; set; }

    public override void _Ready()
    {
        _game = GetNode<Game>("/root/Game");
        _discordManager = GetNode<DiscordManager>("/root/DiscordManager");

        DiscordMenu = GetNode<MenuDiscord>("CenterMenu/DiscordMenu");
        MainMenu = GetNode<MenuMain>("CenterMenu/MainMenu");
        MatchMenu = GetNode<MenuMatch>("CenterMenu/MatchMenu");
        SettingsMenu = GetNode<MenuSettings>("CenterMenu/SettingsMenu");
        OptionsMenu = GetNode<MenuOptions>("CenterMenu/OptionsMenu");

        LeftSideMenu = GetNode<MenuLeftSide>("LeftSideMargin/LeftSideMenu");
        RightSideMenu = GetNode<MenuRightSide>("RightSideMargin/RightSideMenu");

        DiscordMenu.Discord0Button.GrabFocus();

        MainMenu.PlayButton.Connect("pressed", this, "ToggleMatchSettings");
        MainMenu.SettingsButton.Connect("pressed", this, "ToggleSettings");

        MatchMenu.StartButton.Connect("pressed", this, "RequestPlay");
        MatchMenu.MapButton.Connect("pressed", this, "SwitchMap");
        MatchMenu.BackButton.Connect("pressed", this, "ToggleMatchSettings");

        SettingsMenu.DoneButton.Connect("pressed", this, "ToggleSettings");

        OptionsMenu.EndButton.Connect("pressed", this, "RequestEnd");
        OptionsMenu.CloseButton.Connect("pressed", this, "HideOptions");

        RightSideMenu.MembersLeaveButton.Connect("pressed", this, "RequestLeave");
    }

    public void SwitchMap()
    {
        EmitSignal("MapSwitched");
    }

    public void RequestPlay()
    {
        EmitSignal("PlayRequested");
    }

    public void RequestEnd()
    {
        EmitSignal("EndRequested");
    }

    public void RequestLeave()
    {
        EmitSignal("LeaveRequested");
    }

    public void UpdateGameButtons()
    {
        if (_discordManager.IsLobbyOwner())
        {
            MainMenu.PlayButton.Show();
            OptionsMenu.EndButton.Show();
        }
        else
        {
            MainMenu.PlayButton.Hide();
            OptionsMenu.EndButton.Hide();
        }
    }

    public void ShowUserAndMenu()
    {
        MainMenu.Show();
        MainMenu.PlayButton.GrabFocus();
        RightSideMenu.Show();
        LeftSideMenu.AddMessage("Welcome!");
    }

    public void ToggleMatchSettings()
    {
        if (MatchMenu.Visible)
        {
            MatchMenu.Hide();
            MainMenu.Show();
            MainMenu.PlayButton.GrabFocus();
        }
        else
        {
            MatchMenu.Show();
            MainMenu.Hide();
            MatchMenu.BackButton.GrabFocus();
        }
    }

    public void ToggleSettings()
    {
        if (SettingsMenu.Visible)
        {
            SettingsMenu.Hide();
            MainMenu.Show();
            MainMenu.SettingsButton.GrabFocus();

            var settings = new Dictionary<string, object>();
            settings.Add("Vsync", OS.VsyncEnabled);
            settings.Add("Fullscreen", OS.WindowFullscreen);
            _game.SaveSettingsToFile(settings);
        }
        else
        {
            SettingsMenu.Show();
            MainMenu.Hide();
            SettingsMenu.DoneButton.GrabFocus();
        }
    }

    public void ShowOptions()
    {
        if (!OptionsMenu.Visible)
        {
            RightSideMenu.UpdateFriends();
            RightSideMenu.UpdateMembers();
            OptionsMenu.Show();
            RightSideMenu.Show();
            OptionsMenu.CloseButton.GrabFocus();
        }
    }

    public void HideOptions()
    {
        OptionsMenu.Hide();
        RightSideMenu.Hide();
    }

    public void Reset(string msg)
    {
        MainMenu.Show();
        OptionsMenu.Hide();
        RightSideMenu.Show();
        MainMenu.PlayButton.GrabFocus();
        LeftSideMenu.AddMessage(msg);
    }
}
