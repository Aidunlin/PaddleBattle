using Godot;
using Godot.Collections;

public class MenuLeftSide : VBoxContainer
{
    private DiscordManager _discordManager;

    public VBoxContainer MessagesList { get; set; }

    public override void _Ready()
    {
        _discordManager = GetNode<DiscordManager>("/root/DiscordManager");

        MessagesList = GetNode<VBoxContainer>("MessagesScroll/Messages");
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

    public void AcceptInvite(Button button, string id)
    {
        button.Disabled = true;
        _discordManager.AcceptInvite(long.Parse(id));
    }
}
