using Godot;
using GColl = Godot.Collections;

public class Paddle : KinematicBody2D
{
    [Signal] public delegate void Collided();
    [Signal] public delegate void Damaged();

    public bool IsSafe = true;
    public bool IsDashing = false;
    public bool WasDashing = false;
    public bool CanDash = true;
    public Vector2 Velocity = new Vector2();
    public Vector2 InputVelocity = new Vector2();
    public float InputRotation = 0;

    public Area2D BackNode;
    public Timer SafeTimer;
    public Timer DashTimer;
    public Timer DashResetTimer;
    
    public DiscordManager discordManager;

    public override void _Ready()
    {
        discordManager = GetNode<DiscordManager>("/root/DiscordManager");
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
        if (discordManager.IsLobbyOwner())
        {
            Velocity.x = Mathf.Lerp(Velocity.x, InputVelocity.x, (float)0.06);
            Velocity.y = Mathf.Lerp(Velocity.y, InputVelocity.y, (float)0.06);
            Rotation += InputRotation;
            KinematicCollision2D collision = MoveAndCollide(Velocity * delta, false);
            if (collision != null)
            {
                if (((Node)collision.Collider).IsInGroup("balls"))
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
        if (discordManager.IsLobbyOwner() && body.IsInGroup("balls") && !IsSafe)
        {
            EmitSignal("Damaged");
            SafeTimer.Start(2);
            IsSafe = true;
        }
    }
    
    public void SafeTimeout()
    {
        if (discordManager.IsLobbyOwner())
        {
            IsSafe = false;
        }
    }

    public void DashTimeout()
    {
        if (discordManager.IsLobbyOwner())
        {
            IsDashing = false;
            DashResetTimer.Start((float)0.2);
        }
    }

    public void DashResetTimeout()
    {
        if (discordManager.IsLobbyOwner())
        {
            CanDash = true;
        }
    }

    public void SetInputs(GColl.Dictionary inputs)
    {
        if (discordManager.IsLobbyOwner())
        {
            InputVelocity = (Vector2)inputs["velocity"];
            InputRotation = (float)inputs["rotation"];
            if (!(bool)inputs["dash"])
            {
                WasDashing = false;
            }
            if ((bool)inputs["dash"] && CanDash && !WasDashing)
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
