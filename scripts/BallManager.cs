using Godot;
using System;
using Godot.Collections;
using Array = Godot.Collections.Array;

/*
    E 0:00:50.386   System.IndexOutOfRangeException: Index was outside the bounds of the array.
  <C++ Error>   Unhandled exception
  <C++ Source>  :0
  <Stack Trace> :0 @ ()
                Array.cs:472 @ Godot.Collections.Dictionary Godot.Collections.Array`1[[Godot.Collections.Dictionary, GodotSharp, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null]].get_Item(Int32 )()
                BallManager.cs:48 @ void BallManager.UpdateBalls(Godot.Collections.Array`1[Godot.Collections.Dictionary] )()
                :0 @ ()
                Object.cs:379 @ System.Object Godot.Object.Call(System.String , System.Object[] )()
                Main.cs:166 @ void Main.UpdateObjects(System.Object , System.Object )()
                Main.cs:60 @ void Main._PhysicsProcess(Single )()

*/

public class BallManager : Node
{
    public PackedScene BallScene = (PackedScene)GD.Load("res://scenes/ball.tscn");

    public Array<Dictionary> Balls = new Array<Dictionary>();
    public Array<Node2D> Spawns = new Array<Node2D>();
    
    public DiscordManager discordManager;

    public override void _Ready()
    {
        discordManager = GetNode<DiscordManager>("/root/DiscordManager");
    }

    public void CreateBalls()
    {
        for (int i = 0; i < Spawns.Count; i++)
        {
            RigidBody2D ballNode = BallScene.Instance<RigidBody2D>();
            Balls.Add(new Dictionary());
            ballNode.Position = Spawns[i].Position;
            AddChild(ballNode);
        }
    }

    public void UpdateBalls(Array<Dictionary> newBalls)
    {
        for (int i = 0; i < GetChildCount(); i++)
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
                        newBallNode.Position = Spawns[i].Position;
                        AddChild(newBallNode);
                    }
                    Balls[i]["position"] = ballNode.Position;
                }
                else
                {
                    ballNode.Mode = RigidBody2D.ModeEnum.Kinematic;
                    Balls[i]["position"] = newBalls[i]["position"];
                    ballNode.Position = (Vector2)Balls[i]["position"];
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
