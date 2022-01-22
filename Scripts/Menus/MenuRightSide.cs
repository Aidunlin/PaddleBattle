using Godot;
using Godot.Collections;

public class MenuRightSide : VBoxContainer
{
    private DiscordManager _discordManager;

    public Label MembersLabel { get; set; }
    public Button MembersLeaveButton { get; set; }
    public VBoxContainer MembersList { get; set; }
    public VBoxContainer FriendsList { get; set; }
    public Button FriendsRefreshButton { get; set; }

    public override void _Ready()
    {
        _discordManager = GetNode<DiscordManager>("/root/DiscordManager");

        MembersLabel = GetNode<Label>("MembersTitleBar/MembersLabel");
        MembersLeaveButton = GetNode<Button>("MembersTitleBar/Leave");
        MembersList = GetNode<VBoxContainer>("MembersScroll/Members");
        FriendsRefreshButton = GetNode<Button>("FriendsTitleBar/Refresh");
        FriendsList = GetNode<VBoxContainer>("FriendsScroll/Friends");

        FriendsRefreshButton.Connect("pressed", this, "UpdateFriends");
    }

    public void UpdateFriends()
    {
        foreach (Control friend in FriendsList.GetChildren())
        {
            friend.QueueFree();
        }

        Array<Dictionary> friends = _discordManager.GetFriends();

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
        MembersLabel.Text = "Lobby (" + members.Count + "/" + _discordManager.GetLobbyCapacity() + ")";

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
}
