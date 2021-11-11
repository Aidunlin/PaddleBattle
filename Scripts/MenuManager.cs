using Godot;
using Godot.Collections;

public class MenuManager : Control
{
    private Game _game;
    private DiscordManager _discordManager;

    [Signal] public delegate void MapSwitched();
    [Signal] public delegate void EndRequested();

    public MarginContainer MessageWrap;
    public VBoxContainer MessageView;

    public CenterContainer CenterMenuNode;

    public VBoxContainer DiscordMenuNode;
    public Button Discord0Button;
    public Button Discord1Button;

    public VBoxContainer MainMenuNode;
    public Label NameLabel;
    public Button MapButton;
    public Button PlayButton;
    public Button SettingsButton;
    public Button QuitButton;
    public Label VersionNode;

    public VBoxContainer SettingsMenuNode;
    public CheckButton VsyncButton;
    public CheckButton FullscreenButton;
    public Button DoneButton;

    public VBoxContainer OptionsMenuNode;
    public VBoxContainer FriendsList;
    public Button RefreshButton;
    public Button BackButton;
    public Button LeaveButton;

    public MarginContainer InviteWrap;
    public Label InviteName;
    public Button AcceptButton;
    public Button DeclineButton;

    [Export] public long InvitedBy = 0;

    public override void _Ready()
    {
        _game = GetNode<Game>("/root/Game");
        _discordManager = GetNode<DiscordManager>("/root/DiscordManager");

        MessageWrap = GetNode<MarginContainer>("MessageWrap");
        MessageView = MessageWrap.GetNode<VBoxContainer>("MessageView");

        CenterMenuNode = GetNode<CenterContainer>("CenterMenu");

        DiscordMenuNode = CenterMenuNode.GetNode<VBoxContainer>("Discord");
        Discord0Button = DiscordMenuNode.GetNode<Button>("Discord0");
        Discord1Button = DiscordMenuNode.GetNode<Button>("Discord1");

        MainMenuNode = CenterMenuNode.GetNode<VBoxContainer>("Main");
        NameLabel = MainMenuNode.GetNode<Label>("Name");
        PlayButton = MainMenuNode.GetNode<Button>("Play");
        SettingsButton = MainMenuNode.GetNode<Button>("Settings");
        QuitButton = MainMenuNode.GetNode<Button>("Quit");
        VersionNode = MainMenuNode.GetNode<Label>("Version");

        SettingsMenuNode = CenterMenuNode.GetNode<VBoxContainer>("Settings");
        VsyncButton = SettingsMenuNode.GetNode<CheckButton>("Vsync");
        FullscreenButton = SettingsMenuNode.GetNode<CheckButton>("Fullscreen");
        MapButton = SettingsMenuNode.GetNode<Button>("Map");
        DoneButton = SettingsMenuNode.GetNode<Button>("Done");

        OptionsMenuNode = CenterMenuNode.GetNode<VBoxContainer>("Options");
        FriendsList = OptionsMenuNode.GetNode<VBoxContainer>("FriendsWrap/Friends");
        RefreshButton = OptionsMenuNode.GetNode<Button>("Refresh");
        BackButton = OptionsMenuNode.GetNode<Button>("Back");
        LeaveButton = OptionsMenuNode.GetNode<Button>("Leave");

        InviteWrap = GetNode<MarginContainer>("InviteWrap");
        InviteName = InviteWrap.GetNode<Label>("InviteView/Name");
        AcceptButton = InviteWrap.GetNode<Button>("InviteView/Accept");
        DeclineButton = InviteWrap.GetNode<Button>("InviteView/Decline");

        _discordManager.Connect("InviteReceived", this, "ShowInvite");

        DiscordMenuNode.Show();
        Discord0Button.Connect("pressed", this, "StartDiscord", new Array() { "0" });
        Discord1Button.Connect("pressed", this, "StartDiscord", new Array() { "1" });
        Discord0Button.GrabFocus();

        MainMenuNode.Hide();
        PlayButton.Connect("pressed", _discordManager, "CreateLobby");
        SettingsButton.Connect("pressed", this, "ToggleSettings");
        QuitButton.Connect("pressed", GetTree(), "quit");
        VersionNode.Text = Game.Version;

        SettingsMenuNode.Hide();
        VsyncButton.Connect("pressed", this, "ToggleVsync");
        FullscreenButton.Connect("pressed", this, "ToggleFullscreen");
        MapButton.Connect("pressed", this, "SwitchMap");
        MapButton.Text = _game.MapName;
        DoneButton.Connect("pressed", this, "ToggleSettings");

        OptionsMenuNode.Hide();
        RefreshButton.Connect("pressed", this, "UpdateFriends");
        RefreshButton.FocusNeighbourBottom = BackButton.GetPath();
        BackButton.Connect("pressed", this, "HideOptions");
        BackButton.FocusNeighbourTop = RefreshButton.GetPath();
        BackButton.FocusNeighbourBottom = LeaveButton.GetPath();
        LeaveButton.Connect("pressed", this, "RequestEnd");
        LeaveButton.FocusNeighbourTop = BackButton.GetPath();
        LeaveButton.FocusNeighbourBottom = LeaveButton.GetPath();

        InviteWrap.Hide();
        AcceptButton.Connect("pressed", this, "AcceptInvite");
        DeclineButton.Connect("pressed", this, "DeclineInvite");
    }
    
    public void SwitchMap()
    {
        EmitSignal("MapSwitched");
    }

    public void RequestEnd()
    {
        EmitSignal("EndRequested");
    }

    public void StartDiscord(string instance)
    {
        _discordManager.Start(instance);
        DiscordMenuNode.Hide();
    }

    public void ShowUserAndMenu()
    {
        NameLabel.Text = _game.UserName;
        MainMenuNode.Show();
        PlayButton.GrabFocus();
    }

    public void ToggleSettings()
    {
        if (SettingsMenuNode.Visible)
        {
            SettingsMenuNode.Visible = false;
            MainMenuNode.Visible = true;
            SettingsButton.GrabFocus();
        }
        else
        {
            SettingsMenuNode.Visible = true;
            MainMenuNode.Visible = false;
            DoneButton.GrabFocus();
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
        GD.Print(msg);

        Label newMessage = new Label();
        newMessage.Text = msg;
        MessageView.AddChild(newMessage);
        MessageView.MoveChild(newMessage, 0);

        Timer messageTimer = new Timer();
        newMessage.AddChild(messageTimer);
        messageTimer.OneShot = true;
        messageTimer.Connect("timeout", newMessage, "queue_free");
        messageTimer.Start(5);

        if (MessageView.GetChildCount() > 5)
        {
            MessageView.GetChild(MessageView.GetChildCount() - 1).QueueFree();
        }
    }

    public void ShowOptions()
    {
        if (!OptionsMenuNode.Visible)
        {
            OptionsMenuNode.Show();
            if (InvitedBy != 0)
            {
                InviteWrap.Show();
            }
            BackButton.GrabFocus();
            UpdateFriends();
        }
    }

    public void HideOptions()
    {
        OptionsMenuNode.Hide();
        InviteWrap.Hide();
    }

    public void FriendPressed(Control button, string id)
    {
        _discordManager.SendInvite(long.Parse(id));
        button.FindNextValidFocus().GrabFocus();
        button.QueueFree();
    }

    public void UpdateFriends()
    {
        foreach (Node friend in FriendsList.GetChildren())
        {
            friend.QueueFree();
        }
        Array friends = _discordManager.GetFriends();
        foreach (Dictionary friend in friends)
        {
            Button friendButton = new Button();
            friendButton.Text = (string)friend["UserName"];
            friendButton.Connect("pressed", this, "FriendPressed", new Array() { friendButton, friend["Id"] });
            FriendsList.AddChild(friendButton);
        }
    }

    public void ShowInvite(string userId, string userName)
    {
        InvitedBy = long.Parse(userId);
        InviteName.Text = "Invited by " + userName;
        if (!_game.IsPlaying || OptionsMenuNode.Visible)
        {
            InviteWrap.Show();
        }
    }

    public void AcceptInvite()
    {
        InviteWrap.Hide();
        _discordManager.AcceptInvite(InvitedBy);
        InvitedBy = 0;
    }

    public void DeclineInvite()
    {
        InviteWrap.Hide();
        InvitedBy = 0;
    }

    public void Reset(string msg)
    {
        MainMenuNode.Show();
        OptionsMenuNode.Hide();
        PlayButton.GrabFocus();
        AddMessage(msg);
    }
}
