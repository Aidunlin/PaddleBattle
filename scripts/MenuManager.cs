using Godot;
using Godot.Collections;

public class MenuManager : Node
{
    [Signal] public delegate void MapSwitched();
    [Signal] public delegate void EndRequested();

    public Game game;
    public DiscordManager discordManager;

    public long InvitedBy = 0;

    public Control MessageWrap;
    public Control MessageView;
    public Control InviteWrap;
    public Label InviteName;
    public Control AcceptButton;
    public Control DeclineButton;
    public Control MenuNode;

    public Control DiscordMenuNode;
    public Control Discord0Button;
    public Control Discord1Button;

    public Control MainMenuNode;
    public Label NameLabel;
    public Button MapButton;
    public Control PlayButton;
    public Control QuitButton;
    public Label VersionNode;

    public Control OptionsMenuNode;
    public Control FriendsList;
    public Control RefreshButton;
    public Control BackButton;
    public Control LeaveButton;

    public override void _Ready()
    {
        game = GetNode<Game>("/root/Game");
        discordManager = GetNode<DiscordManager>("/root/DiscordManager");

        MessageWrap = GetNode<Control>("MessageWrap");
        MessageView = GetNode<Control>("MessageWrap/MessageView");
        InviteWrap = GetNode<Control>("InviteWrap");
        InviteName = GetNode<Label>("InviteWrap/InviteView/Name");
        AcceptButton = GetNode<Control>("InviteWrap/InviteView/Accept");
        DeclineButton = GetNode<Control>("InviteWrap/InviteView/Decline");
        MenuNode = GetNode<Control>("Menu");

        DiscordMenuNode = GetNode<Control>("Menu/Discord");
        Discord0Button = GetNode<Control>("Menu/Discord/Discord0");
        Discord1Button = GetNode<Control>("Menu/Discord/Discord1");

        MainMenuNode = GetNode<Control>("Menu/Main");
        NameLabel = GetNode<Label>("Menu/Main/Name");
        MapButton = GetNode<Button>("Menu/Main/Map");
        PlayButton = GetNode<Control>("Menu/Main/Play");
        QuitButton = GetNode<Control>("Menu/Main/Quit");
        VersionNode = GetNode<Label>("Menu/Main/Version");

        OptionsMenuNode = GetNode<Control>("Menu/Options");
        FriendsList = GetNode<Control>("Menu/Options/FriendsWrap/Friends");
        RefreshButton = GetNode<Control>("Menu/Options/Refresh");
        BackButton = GetNode<Control>("Menu/Options/Back");
        LeaveButton = GetNode<Control>("Menu/Options/Leave");

        DiscordMenuNode.Show();;
        MainMenuNode.Hide();
        OptionsMenuNode.Hide();
        InviteWrap.Hide();
        discordManager.Connect("Error", this, "AddMessage");
        discordManager.Connect("InviteReceived", this, "ShowInvite");
        AcceptButton.Connect("pressed", this, "AcceptInvite");
        DeclineButton.Connect("pressed", this, "DeclineInvite");
        Discord0Button.GrabFocus();
        Discord0Button.Connect("pressed", this, "StartDiscord", new Array(){"0"});
        Discord1Button.Connect("pressed", this, "StartDiscord", new Array(){"1"});
        MapButton.Connect("pressed", this, "SwitchMap");
        MapButton.Text = game.Map;
        PlayButton.Connect("pressed", discordManager, "CreateLobby");
        QuitButton.Connect("pressed", GetTree(), "quit");
        VersionNode.Text = Game.Version;
        RefreshButton.Connect("pressed", this, "UpdateFriends");
        BackButton.Connect("pressed", this, "HideOptions");
        LeaveButton.Connect("pressed", this, "RequestEnd");
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
            friendButton.Connect("pressed", this, "FriendPressed", new Array(){friendButton, friend["id"]});
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
