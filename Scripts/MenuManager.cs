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
    public VBoxContainer InviteMenu;
    public Label InviteNameLabel;
    public Button InviteAcceptButton;
    public Button InviteDeclineButton;

    public CenterContainer CenterMenu;

    public VBoxContainer DiscordMenu;
    public Button Discord0Button;
    public Button Discord1Button;

    public VBoxContainer MainMenu;
    public Button MainPlayButton;
    public Button MainSettingsButton;
    public Button MainQuitButton;
    public Label MainVersionLabel;

    public VBoxContainer SettingsMenu;
    public CheckButton SettingsVsyncButton;
    public CheckButton SettingsFullscreenButton;
    public Button SettingsMapButton;
    public Button SettingsDoneButton;

    public VBoxContainer OptionsMenu;
    public Button OptionsEndButton;
    public Button OptionsCloseButton;
    public Button OptionsLeaveButton;

    public VBoxContainer RightSideMenu;
    public VBoxContainer MembersList;
    public VBoxContainer FriendsList;
    public Button FriendsRefreshButton;

    [Export] public long InvitedBy = 0;

    public override void _Ready()
    {
        _game = GetNode<Game>("/root/Game");
        _discordManager = GetNode<DiscordManager>("/root/DiscordManager");

        MessagesList = GetNode<VBoxContainer>("LeftSideMargin/LeftSide/MessagesScroll/Messages");
        InviteMenu = GetNode<VBoxContainer>("LeftSideMargin/LeftSide/Invite");
        InviteNameLabel = InviteMenu.GetNode<Label>("Name");
        InviteAcceptButton = InviteMenu.GetNode<Button>("Accept");
        InviteDeclineButton = InviteMenu.GetNode<Button>("Decline");

        CenterMenu = GetNode<CenterContainer>("CenterMenu");

        DiscordMenu = CenterMenu.GetNode<VBoxContainer>("Discord");
        Discord0Button = DiscordMenu.GetNode<Button>("Discord0");
        Discord1Button = DiscordMenu.GetNode<Button>("Discord1");

        MainMenu = CenterMenu.GetNode<VBoxContainer>("Main");
        MainPlayButton = MainMenu.GetNode<Button>("Play");
        MainSettingsButton = MainMenu.GetNode<Button>("Settings");
        MainQuitButton = MainMenu.GetNode<Button>("Quit");
        MainVersionLabel = MainMenu.GetNode<Label>("Version");

        SettingsMenu = CenterMenu.GetNode<VBoxContainer>("Settings");
        SettingsVsyncButton = SettingsMenu.GetNode<CheckButton>("Vsync");
        SettingsFullscreenButton = SettingsMenu.GetNode<CheckButton>("Fullscreen");
        SettingsMapButton = SettingsMenu.GetNode<Button>("Map");
        SettingsDoneButton = SettingsMenu.GetNode<Button>("Done");

        OptionsMenu = CenterMenu.GetNode<VBoxContainer>("Options");
        OptionsEndButton = OptionsMenu.GetNode<Button>("End");
        OptionsCloseButton = OptionsMenu.GetNode<Button>("Close");
        OptionsLeaveButton = OptionsMenu.GetNode<Button>("Leave");

        RightSideMenu = GetNode<VBoxContainer>("RightSideMargin/RightSide");
        MembersList = RightSideMenu.GetNode<VBoxContainer>("MembersScroll/Members");
        FriendsList = RightSideMenu.GetNode<VBoxContainer>("FriendsScroll/Friends");
        FriendsRefreshButton = RightSideMenu.GetNode<Button>("Refresh");

        InviteMenu.Hide();
        InviteAcceptButton.Connect("pressed", this, "AcceptInvite");
        InviteDeclineButton.Connect("pressed", this, "DeclineInvite");

        DiscordMenu.Show();
        Discord0Button.Connect("pressed", this, "StartDiscord", new Array() { "0" });
        Discord1Button.Connect("pressed", this, "StartDiscord", new Array() { "1" });
        Discord0Button.GrabFocus();

        MainMenu.Hide();
        MainPlayButton.Connect("pressed", this, "RequestPlay");
        MainSettingsButton.Connect("pressed", this, "ToggleSettings");
        MainQuitButton.Connect("pressed", GetTree(), "quit");
        MainVersionLabel.Text = Game.Version;

        SettingsMenu.Hide();
        SettingsVsyncButton.Connect("pressed", this, "ToggleVsync");
        SettingsFullscreenButton.Connect("pressed", this, "ToggleFullscreen");
        SettingsMapButton.Connect("pressed", this, "SwitchMap");
        SettingsDoneButton.Connect("pressed", this, "ToggleSettings");

        OptionsMenu.Hide();
        OptionsEndButton.Connect("pressed", this, "RequestEnd");
        OptionsCloseButton.Connect("pressed", this, "HideOptions");
        OptionsLeaveButton.Connect("pressed", this, "RequestLeave");

        RightSideMenu.Hide();
        FriendsRefreshButton.Connect("pressed", this, "UpdateFriends");

        Dictionary<string, object> options = _game.LoadOptionsFromFile();
        OS.VsyncEnabled = (bool)options["Vsync"];
        SettingsVsyncButton.Pressed = OS.VsyncEnabled;
        OS.WindowFullscreen = (bool)options["Fullscreen"];
        SettingsFullscreenButton.Pressed = OS.WindowFullscreen;
        SettingsMapButton.Text = (string)options["Map"];
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
            options.Add("Map", _game.MapName);
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

    public void AddMessage(string msg = "")
    {
        Label newMessage = new Label();
        newMessage.Text = msg;
        MessagesList.AddChild(newMessage);
        MessagesList.MoveChild(newMessage, 0);

        Timer messageTimer = new Timer();
        newMessage.AddChild(messageTimer);
        messageTimer.OneShot = true;
        messageTimer.Connect("timeout", newMessage, "queue_free");
        messageTimer.Start(5);
    }

    public void ShowOptions()
    {
        if (!OptionsMenu.Visible)
        {
            OptionsMenu.Show();
            RightSideMenu.Show();

            if (InvitedBy != 0)
            {
                InviteMenu.Show();
            }

            OptionsCloseButton.GrabFocus();
            UpdateFriends();
            UpdateMembers();
        }
    }

    public void HideOptions()
    {
        OptionsMenu.Hide();
        RightSideMenu.Hide();
        InviteMenu.Hide();
    }

    public void FriendPressed(Button button, string id)
    {
        button.Disabled = true;
        _discordManager.SendInvite(long.Parse(id));
    }

    public void UpdateFriends()
    {
        foreach (Node friend in FriendsList.GetChildren())
        {
            friend.QueueFree();
        }

        foreach (Dictionary friend in _discordManager.GetFriends())
        {
            HBoxContainer hBox = new HBoxContainer();
            FriendsList.AddChild(hBox);

            Label usernameLabel = new Label();
            usernameLabel.Text = (string)friend["Username"];
            usernameLabel.SizeFlagsHorizontal = (int)SizeFlags.ExpandFill;
            hBox.AddChild(usernameLabel);

            Button inviteButton = new Button();
            inviteButton.Text = "Invite";
            inviteButton.Connect("pressed", this, "FriendPressed", new Array() { inviteButton, friend["Id"] });
            hBox.AddChild(inviteButton);
        }
    }

    public void UpdateMembers()
    {
        foreach (Node member in MembersList.GetChildren())
        {
            member.QueueFree();
        }

        Label youLabel = new Label();
        youLabel.Text = _game.Username + " (you)";
        MembersList.AddChild(youLabel);

        foreach (Dictionary member in _discordManager.GetMembers())
        {
            if (_game.UserId.ToString() == (string)member["Id"])
            {
                continue;
            }
            
            Label memberLabel = new Label();
            memberLabel.Text = (string)member["Username"];
            MembersList.AddChild(memberLabel);
        }
    }

    public void ShowInvite(string userId, string username)
    {
        InvitedBy = long.Parse(userId);
        InviteNameLabel.Text = "Invited by " + username;

        if (!_game.IsPlaying || OptionsMenu.Visible)
        {
            InviteMenu.Show();
        }
    }

    public void AcceptInvite()
    {
        InviteMenu.Hide();
        _discordManager.AcceptInvite(InvitedBy);
        InvitedBy = 0;
    }

    public void DeclineInvite()
    {
        InviteMenu.Hide();
        InvitedBy = 0;
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
