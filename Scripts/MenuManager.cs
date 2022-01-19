using Godot;
using Godot.Collections;

public class MenuManager : Control
{
    private Game _game;
    private DiscordManager _discordManager;

    [Signal] public delegate void MapSwitched();
    [Signal] public delegate void PlayRequested();
    [Signal] public delegate void EndRequested();
    [Signal] public delegate void LeaveRequested();

    public VBoxContainer MessagesList;

    public CenterContainer CenterMenu;

    public VBoxContainer DiscordMenu;
    public Button Discord0Button;
    public Button Discord1Button;

    public VBoxContainer MainMenu;
    public Button MainPlayButton;
    public Button MainSettingsButton;
    public Button MainQuitButton;
    public Label MainVersionLabel;

    public VBoxContainer MatchMenu;
    public Button MatchStartButton;
    public Button MatchMapButton;
    public Button MatchBackButton;

    public VBoxContainer SettingsMenu;
    public CheckButton SettingsVsyncButton;
    public CheckButton SettingsFullscreenButton;
    public Button SettingsDoneButton;

    public VBoxContainer OptionsMenu;
    public Button OptionsEndButton;
    public Button OptionsCloseButton;
    public Button OptionsLeaveButton;

    public VBoxContainer RightSideMenu;
    public Label MembersLabel;
    public VBoxContainer MembersList;
    public Label FriendsLabel;
    public VBoxContainer FriendsList;
    public Button FriendsRefreshButton;

    public override void _Ready()
    {
        _game = GetNode<Game>("/root/Game");
        _discordManager = GetNode<DiscordManager>("/root/DiscordManager");

        MessagesList = GetNode<VBoxContainer>("LeftSideMargin/LeftSide/MessagesScroll/Messages");

        CenterMenu = GetNode<CenterContainer>("CenterMenu");

        DiscordMenu = CenterMenu.GetNode<VBoxContainer>("Discord");
        Discord0Button = DiscordMenu.GetNode<Button>("Discord0");
        Discord1Button = DiscordMenu.GetNode<Button>("Discord1");

        MainMenu = CenterMenu.GetNode<VBoxContainer>("Main");
        MainPlayButton = MainMenu.GetNode<Button>("Play");
        MainSettingsButton = MainMenu.GetNode<Button>("Settings");
        MainQuitButton = MainMenu.GetNode<Button>("Quit");
        MainVersionLabel = MainMenu.GetNode<Label>("Version");

        MatchMenu = CenterMenu.GetNode<VBoxContainer>("Match");
        MatchStartButton = MatchMenu.GetNode<Button>("Start");
        MatchMapButton = MatchMenu.GetNode<Button>("Map");
        MatchBackButton = MatchMenu.GetNode<Button>("Back");

        SettingsMenu = CenterMenu.GetNode<VBoxContainer>("Settings");
        SettingsVsyncButton = SettingsMenu.GetNode<CheckButton>("Vsync");
        SettingsFullscreenButton = SettingsMenu.GetNode<CheckButton>("Fullscreen");
        SettingsDoneButton = SettingsMenu.GetNode<Button>("Done");

        OptionsMenu = CenterMenu.GetNode<VBoxContainer>("Options");
        OptionsEndButton = OptionsMenu.GetNode<Button>("End");
        OptionsCloseButton = OptionsMenu.GetNode<Button>("Close");
        OptionsLeaveButton = OptionsMenu.GetNode<Button>("Leave");

        RightSideMenu = GetNode<VBoxContainer>("RightSideMargin/RightSide");
        MembersLabel = RightSideMenu.GetNode<Label>("MembersLabel");
        MembersList = RightSideMenu.GetNode<VBoxContainer>("MembersScroll/Members");
        FriendsLabel = RightSideMenu.GetNode<Label>("FriendsLabel");
        FriendsList = RightSideMenu.GetNode<VBoxContainer>("FriendsScroll/Friends");
        FriendsRefreshButton = RightSideMenu.GetNode<Button>("Refresh");

        DiscordMenu.Show();
        Discord0Button.Connect("pressed", this, "StartDiscord", new Array() { "0" });
        Discord1Button.Connect("pressed", this, "StartDiscord", new Array() { "1" });
        Discord0Button.GrabFocus();

        MainMenu.Hide();
        MainPlayButton.Connect("pressed", this, "ToggleMatchSettings");
        MainSettingsButton.Connect("pressed", this, "ToggleSettings");
        MainQuitButton.Connect("pressed", GetTree(), "quit");
        MainVersionLabel.Text = Game.Version;

        MatchMenu.Hide();
        MatchStartButton.Connect("pressed", this, "RequestPlay");
        MatchMapButton.Connect("pressed", this, "SwitchMap");
        MatchBackButton.Connect("pressed", this, "ToggleMatchSettings");

        SettingsMenu.Hide();
        SettingsVsyncButton.Connect("pressed", this, "ToggleVsync");
        SettingsFullscreenButton.Connect("pressed", this, "ToggleFullscreen");
        SettingsDoneButton.Connect("pressed", this, "ToggleSettings");

        OptionsMenu.Hide();
        OptionsEndButton.Connect("pressed", this, "RequestEnd");
        OptionsCloseButton.Connect("pressed", this, "HideOptions");
        OptionsLeaveButton.Connect("pressed", this, "RequestLeave");

        RightSideMenu.Hide();
        FriendsRefreshButton.Connect("pressed", this, "UpdateFriends");

        Dictionary<string, object> options = _game.LoadOptionsFromFile(MatchMapButton.Text);
        OS.VsyncEnabled = (bool)options["Vsync"];
        SettingsVsyncButton.Pressed = OS.VsyncEnabled;
        OS.WindowFullscreen = (bool)options["Fullscreen"];
        SettingsFullscreenButton.Pressed = OS.WindowFullscreen;
        MatchMapButton.Text = (string)options["Map"];
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
            MainPlayButton.Show();
            OptionsEndButton.Show();
            OptionsLeaveButton.Hide();
        }
        else
        {
            MainPlayButton.Hide();
            OptionsEndButton.Hide();
            OptionsLeaveButton.Show();
        }
    }

    public void StartDiscord(string instance)
    {
        _discordManager.Start(instance);
        DiscordMenu.Hide();
    }

    public void ShowUserAndMenu()
    {
        MainMenu.Show();
        MainPlayButton.GrabFocus();
        RightSideMenu.Show();
        AddMessage("Welcome!");
    }

    public void ToggleMatchSettings()
    {
        if (MatchMenu.Visible)
        {
            MatchMenu.Visible = false;
            MainMenu.Visible = true;
            MainPlayButton.GrabFocus();
        }
        else
        {
            MatchMenu.Visible = true;
            MainMenu.Visible = false;
            MatchBackButton.GrabFocus();
        }
    }

    public void ToggleSettings()
    {
        if (SettingsMenu.Visible)
        {
            SettingsMenu.Visible = false;
            MainMenu.Visible = true;
            MainSettingsButton.GrabFocus();

            Dictionary<string, object> options = new Dictionary<string, object>();
            options.Add("Vsync", OS.VsyncEnabled);
            options.Add("Fullscreen", OS.WindowFullscreen);
            _game.SaveOptionsToFile(options);
        }
        else
        {
            SettingsMenu.Visible = true;
            MainMenu.Visible = false;
            SettingsDoneButton.GrabFocus();
        }
    }

    public void ToggleVsync()
    {
        OS.VsyncEnabled = !OS.VsyncEnabled;
    }

    public void ToggleFullscreen()
    {
        OS.WindowFullscreen = !OS.WindowFullscreen;
    }

    public void AddMessage(string msg)
    {
        Label messageLabel = new Label();
        messageLabel.Text = msg;
        messageLabel.Autowrap = true;
        MessagesList.AddChild(messageLabel);
        MessagesList.MoveChild(messageLabel, 0);

        Timer messageTimer = new Timer();
        messageLabel.AddChild(messageTimer);
        messageTimer.OneShot = true;
        messageTimer.Connect("timeout", messageLabel, "queue_free");
        messageTimer.Start(5);
    }

    public void AddInvite(string userId, string username)
    {
        HBoxContainer hBox = new HBoxContainer();
        MessagesList.AddChild(hBox);
        MessagesList.MoveChild(hBox, 0);
        
        Label messageLabel = new Label();
        messageLabel.Text = "Invited by " + username;
        messageLabel.Autowrap = true;
        messageLabel.SizeFlagsHorizontal = (int)SizeFlags.ExpandFill;
        hBox.AddChild(messageLabel);

        Button acceptButton = new Button();
        acceptButton.Text = "Accept";
        acceptButton.Connect("pressed", this, "AcceptInvite", new Array { acceptButton, userId });
        hBox.AddChild(acceptButton);

        Timer messageTimer = new Timer();
        hBox.AddChild(messageTimer);
        messageTimer.OneShot = true;
        messageTimer.Connect("timeout", hBox, "queue_free");
        messageTimer.Start(10);
    }

    public void ShowOptions()
    {
        if (!OptionsMenu.Visible)
        {
            UpdateFriends();
            UpdateMembers();
            OptionsMenu.Show();
            RightSideMenu.Show();
            OptionsCloseButton.GrabFocus();
        }
    }

    public void HideOptions()
    {
        OptionsMenu.Hide();
        RightSideMenu.Hide();
    }

    public void UpdateFriends()
    {
        foreach (Control friend in FriendsList.GetChildren())
        {
            friend.QueueFree();
        }

        Array<Dictionary> friends = _discordManager.GetFriends();
        FriendsLabel.Text = "Friends (" + friends.Count + " online)";

        foreach (Dictionary friend in friends)
        {
            HBoxContainer hBox = new HBoxContainer();
            FriendsList.AddChild(hBox);

            Label usernameLabel = new Label();
            usernameLabel.Text = (string)friend["Username"];
            usernameLabel.SizeFlagsHorizontal = (int)SizeFlags.ExpandFill;
            hBox.AddChild(usernameLabel);

            Button inviteButton = new Button();
            inviteButton.Text = "Invite";
            inviteButton.Connect("pressed", this, "SendInvite", new Array() { inviteButton, friend["Id"] });
            hBox.AddChild(inviteButton);
        }
    }

    public void UpdateMembers()
    {
        foreach (Node member in MembersList.GetChildren())
        {
            member.QueueFree();
        }

        Array<Dictionary> members = _discordManager.GetMembers();
        MembersLabel.Text = "Lobby (" + members.Count + "/" + _discordManager.GetLobbySize() + ")";

        foreach (Dictionary member in members)
        {
            Label memberLabel = new Label();
            memberLabel.Text = (string)member["Username"];
            MembersList.AddChild(memberLabel);

            if ((string)member["Id"] == _discordManager.GetUserId().ToString())
            {
                memberLabel.Text += " (you)";
            }

            if ((string)member["Id"] == _discordManager.GetLobbyOwnerId().ToString())
            {
                memberLabel.Text = "* " + memberLabel.Text;
            }
        }
    }

    public void SendInvite(Button button, string id)
    {
        button.Disabled = true;
        _discordManager.SendInvite(long.Parse(id));
    }

    public void AcceptInvite(Button button, string id)
    {
        button.Disabled = true;
        _discordManager.AcceptInvite(long.Parse(id));
    }

    public void Reset(string msg)
    {
        MainMenu.Show();
        OptionsMenu.Hide();
        RightSideMenu.Show();
        MainPlayButton.GrabFocus();
        AddMessage(msg);
    }
}
