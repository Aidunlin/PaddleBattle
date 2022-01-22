using Godot;
using Godot.Collections;

public class Paddle : KinematicBody2D
{
    private DiscordManager _discordManager;

    [Signal] public delegate void Damaged();

    [Export] public string Id { get; set; }
    [Export] public int Pad { get; set; }
    [Export] public int MaxHealth { get; set; }
    [Export] public int Health { get; set; }

    [Export] public Vector2 Velocity { get; set; } = new Vector2();
    [Export] public Vector2 InputVelocity { get; set; } = new Vector2();
    [Export] public float InputRotation { get; set; } = 0;

    [Export] public bool IsSafe { get; set; } = true;
    [Export] public bool IsDashing { get; set; } = false;
    [Export] public bool WasDashing { get; set; } = false;
    [Export] public bool CanDash { get; set; } = true;
    
    public Area2D BackNode { get; set; }
    public Timer SafeTimer { get; set; }
    public Timer DashTimer { get; set; }
    public Timer DashResetTimer { get; set; }

    public override void _Ready()
    {
        _discordManager = GetNode<DiscordManager>("/root/DiscordManager");

        BackNode = GetNode<Area2D>("Back");
        SafeTimer = GetNode<Timer>("SafeTimer");
        DashTimer = GetNode<Timer>("DashTimer");
        DashResetTimer = GetNode<Timer>("DashResetTimer");

        BackNode.Connect("body_entered", this, "BackCollided");
        SafeTimer.Connect("timeout", this, "SafeTimeout");
        SafeTimer.Start(3);
        DashTimer.Connect("timeout", this, "DashTimeout");
        DashResetTimer.Connect("timeout", this, "DashResetTimeout");
    }

    public override void _PhysicsProcess(float delta)
    {
        if (_discordManager.IsLobbyOwner())
        {
            Velocity = Velocity.LinearInterpolate(InputVelocity, (float)0.06);
            Rotation += InputRotation;
            KinematicCollision2D collision = MoveAndCollide(Velocity * delta, false);

            if (collision != null)
            {
                if (((Node2D)collision.Collider).IsInGroup("balls"))
                {
                    int modifier = IsDashing ? 200 : 100;
                    ((RigidBody2D)collision.Collider).ApplyCentralImpulse(-collision.Normal * modifier);
                }
                else
                {
                    Velocity = Velocity.Bounce(collision.Normal);
                }
            }
        }
    }

    public void BackCollided(Node body)
    {
        if (_discordManager.IsLobbyOwner() && body.IsInGroup("balls") && !IsSafe)
        {
            EmitSignal("Damaged");
            SafeTimer.Start(2);
            IsSafe = true;
        }
    }

    public void SafeTimeout()
    {
        if (_discordManager.IsLobbyOwner())
        {
            IsSafe = false;
        }
    }

    public void DashTimeout()
    {
        if (_discordManager.IsLobbyOwner())
        {
            IsDashing = false;
            DashResetTimer.Start((float)0.2);
        }
    }

    public void DashResetTimeout()
    {
        if (_discordManager.IsLobbyOwner())
        {
            CanDash = true;
        }
    }

    public void SetInputs(Dictionary inputs)
    {
        if (_discordManager.IsLobbyOwner())
        {
            InputVelocity = (Vector2)inputs["Velocity"];
            InputRotation = (float)inputs["Rotation"];

            if (!(bool)inputs["Dash"])
            {
                WasDashing = false;
            }

            if ((bool)inputs["Dash"] && CanDash && !WasDashing)
            {
                CanDash = false;
                IsDashing = true;
                DashTimer.Start((float)0.1);
            }

            if (IsDashing)
            {
                WasDashing = true;
                InputVelocity *= 3;
            }
        }
    }
}
