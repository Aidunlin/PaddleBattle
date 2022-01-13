using Godot;
using Godot.Collections;

public class Paddle : KinematicBody2D
{
    private DiscordManager _discordManager;

    [Signal] public delegate void Collided();
    [Signal] public delegate void Damaged();

    [Export] public bool IsSafe = true;
    [Export] public bool IsDashing = false;
    [Export] public bool WasDashing = false;
    [Export] public bool CanDash = true;
    [Export] public Vector2 Velocity = new Vector2();
    [Export] public Vector2 InputVelocity = new Vector2();
    [Export] public float InputRotation = 0;

    [Export] public string Id;
    [Export] public int Pad;
    [Export] public int MaxHealth;
    [Export] public int Health;

    public Area2D BackNode;
    public Timer SafeTimer;
    public Timer DashTimer;
    public Timer DashResetTimer;

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

                EmitSignal("Collided");
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
