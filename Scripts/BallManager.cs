using Godot;
using Godot.Collections;

public class BallManager : Node
{
    private DiscordManager _discordManager;

    public readonly PackedScene BallScene = (PackedScene)GD.Load("res://Scenes/Ball.tscn");

    [Export] public Array Spawns { get; set; } = new Array();

    public override void _Ready()
    {
        _discordManager = GetNode<DiscordManager>("/root/DiscordManager");
    }

    public void CreateBalls()
    {
        foreach (Node2D spawn in Spawns)
        {
            var ballNode = BallScene.Instance<RigidBody2D>();
            ballNode.Position = spawn.Position;
            AddChild(ballNode);
        }
    }

    public Array GetBalls()
    {
        var balls = new Array();

        foreach (RigidBody2D ball in GetChildren())
        {
            balls.Add(ball.Position);
        }

        return balls;
    }

    public void UpdateBalls(Array newBalls)
    {
        var ballCount = GetChildCount();

        for (var i = 0; i < ballCount; i++)
        {
            var ballNode = GetChildOrNull<RigidBody2D>(i);

            if (ballNode != null)
            {
                if (_discordManager.IsLobbyOwner())
                {
                    ballNode.Mode = RigidBody2D.ModeEnum.Character;

                    if (ballNode.Position.Length() > 4096)
                    {
                        ballNode.QueueFree();
                        var newBallNode = BallScene.Instance<RigidBody2D>();
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
        foreach (Node ball in GetChildren())
        {
            ball.QueueFree();
        }

        Spawns.Clear();
    }
}
