using Godot;
using Godot.Collections;

public class BallManager : Node
{
    public PackedScene BallScene = (PackedScene)GD.Load("res://Scenes/Ball.tscn");

    public Array Balls = new Array();
    public Array Spawns = new Array();
    
    public DiscordManager discordManager;

    public override void _Ready()
    {
        discordManager = GetNode<DiscordManager>("/root/DiscordManager");
    }

    public void CreateBalls()
    {
        foreach (Node2D spawn in Spawns)
        {
            RigidBody2D ballNode = BallScene.Instance<RigidBody2D>();
            Balls.Add(new Vector2());
            ballNode.Position = spawn.Position;
            AddChild(ballNode);
        }
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
                    Balls[i] = ballNode.Position;
                }
                else
                {
                    ballNode.Mode = RigidBody2D.ModeEnum.Kinematic;
                    Balls[i] = (Vector2)newBalls[i];
                    ballNode.Position = (Vector2)Balls[i];
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
        Balls.Clear();
        Spawns.Clear();
    }
}
