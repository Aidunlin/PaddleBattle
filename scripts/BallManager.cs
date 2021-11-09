using Godot;
using Godot.Collections;

public class BallManager : Node
{
    public DiscordManager discordManager;

    public PackedScene BallScene = (PackedScene)GD.Load("res://Scenes/Ball.tscn");

    [Export] public Array Spawns = new Array();

    public override void _Ready()
    {
        discordManager = GetNode<DiscordManager>("/root/DiscordManager");
    }

    public void CreateBalls()
    {
        foreach (Node2D spawn in Spawns)
        {
            RigidBody2D ballNode = BallScene.Instance<RigidBody2D>();
            ballNode.Position = spawn.Position;
            AddChild(ballNode);
        }
    }

    public Array GetBalls()
    {
        Array balls = new Array();
        foreach (RigidBody2D ball in GetChildren())
        {
            balls.Add(ball.Position);
        }
        return balls;
    }

    public void UpdateBalls(Array newBalls)
    {
        int ballCount = GetChildCount();
        for (int i = 0; i < ballCount; i++)
        {
            RigidBody2D ballNode = GetChildOrNull<RigidBody2D>(i);
            if (ballNode != null)
            {
                if (discordManager.IsLobbyOwner())
                {
                    ballNode.Mode = RigidBody2D.ModeEnum.Character;
                    if (ballNode.Position.Length() > 4096)
                    {
                        ballNode.QueueFree();
                        RigidBody2D newBallNode = BallScene.Instance<RigidBody2D>();
                        newBallNode.Position = ((Node2D)Spawns[i]).Position;
                        AddChild(newBallNode);
                    }
                }
                else
                {
                    ballNode.Mode = RigidBody2D.ModeEnum.Kinematic;
                    ballNode.Position = (Vector2)newBalls[i];
                }
            }
        }
    }

    public void Reset()
    {
        foreach (RigidBody2D ball in GetChildren())
        {
            ball.QueueFree();
        }
        Spawns.Clear();
    }
}
