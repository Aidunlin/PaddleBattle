using Godot;
using Godot.Collections;

public class MenuManager : Control
{
    public Game game;
    public DiscordManager discordManager;

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
    public Button QuitButton;
    public Label VersionNode;

    public VBoxContainer OptionsMenuNode;
    public VBoxContainer FriendsList;
    public Button RefreshButton;
    public Button BackButton;
    public Button LeaveButton;

    public MarginContainer InviteWrap;
    public Label InviteName;
    public Button AcceptButton;
    public Button DeclineButton;

    public long InvitedBy = 0;

    public override void _Ready()
    {
        game = GetNode<Game>("/root/Game");
        discordManager = GetNode<DiscordManager>("/root/DiscordManager");

        MessageWrap = GetNode<MarginContainer>("MessageWrap");
        MessageView = MessageWrap.GetNode<VBoxContainer>("MessageView");

        CenterMenuNode = GetNode<CenterContainer>("CenterMenu");

        DiscordMenuNode = CenterMenuNode.GetNode<VBoxContainer>("Discord");
        Discord0Button = DiscordMenuNode.GetNode<Button>("Discord0");
        Discord1Button = DiscordMenuNode.GetNode<Button>("Discord1");

        MainMenuNode = CenterMenuNode.GetNode<VBoxContainer>("Main");
        NameLabel = MainMenuNode.GetNode<Label>("Name");
        MapButton = MainMenuNode.GetNode<Button>("Map");
        PlayButton = MainMenuNode.GetNode<Button>("Play");
        QuitButton = MainMenuNode.GetNode<Button>("Quit");
        VersionNode = MainMenuNode.GetNode<Label>("Version");

        OptionsMenuNode = CenterMenuNode.GetNode<VBoxContainer>("Options");
        FriendsList = OptionsMenuNode.GetNode<VBoxContainer>("FriendsWrap/Friends");
        RefreshButton = OptionsMenuNode.GetNode<Button>("Refresh");
        BackButton = OptionsMenuNode.GetNode<Button>("Back");
        LeaveButton = OptionsMenuNode.GetNode<Button>("Leave");

        InviteWrap = GetNode<MarginContainer>("InviteWrap");
        InviteName = InviteWrap.GetNode<Label>("InviteView/Name");
        AcceptButton = InviteWrap.GetNode<Button>("InviteView/Accept");
        DeclineButton = InviteWrap.GetNode<Button>("InviteView/Decline");

        discordManager.Connect("Error", this, "AddMessage");
        discordManager.Connect("InviteReceived", this, "ShowInvite");

        DiscordMenuNode.Show();
        Discord0Button.Connect("pressed", this, "StartDiscord", new Array() { "0" });
        Discord1Button.Connect("pressed", this, "StartDiscord", new Array() { "1" });
        Discord0Button.GrabFocus();

        MainMenuNode.Hide();
        MapButton.Connect("pressed", this, "SwitchMap");
        MapButton.Text = game.Map;
        PlayButton.Connect("pressed", discordManager, "CreateLobby");
        QuitButton.Connect("pressed", GetTree(), "quit");
        VersionNode.Text = Game.Version;

        OptionsMenuNode.Hide();
        RefreshButton.Connect("pressed", this, "UpdateFriends");
        BackButton.Connect("pressed", this, "HideOptions");
        LeaveButton.Connect("pressed", this, "RequestEnd");

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
        discordManager.Start(instance);
        DiscordMenuNode.Hide();
    }

    public void ShowUserAndMenu()
    {
        NameLabel.Text = game.UserName;
        MainMenuNode.Show();
        PlayButton.GrabFocus();
    }

    public void AddMessage(string msg = "", bool err = false)
    {
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
        if (err)
        {
            GD.PrintErr(msg);
        }
        else
        {
            GD.Print(msg);
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
        discordManager.SendInvite(long.Parse(id));
        button.FindNextValidFocus().GrabFocus();
        button.QueueFree();
    }

    public void UpdateFriends()
    {
        foreach (Node friend in FriendsList.GetChildren())
        {
            friend.QueueFree();
        }
        Array friends = discordManager.GetFriends();
        foreach (Dictionary friend in friends)
        {
            Button friendButton = new Button();
            friendButton.Text = (string)friend["user_name"];
            friendButton.Connect("pressed", this, "FriendPressed", new Array() { friendButton, friend["id"] });
            FriendsList.AddChild(friendButton);
        }
    }

    public void ShowInvite(string userId, string userName)
    {
        InvitedBy = long.Parse(userId);
        InviteName.Text = "Invited by " + userName;
        if (!game.IsPlaying || OptionsMenuNode.Visible)
        {
            InviteWrap.Show();
        }
    }

    public void AcceptInvite()
    {
        InviteWrap.Hide();
        discordManager.AcceptInvite(InvitedBy);
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
