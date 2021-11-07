using Godot;
using System;
using Godot.Collections;
using Array = Godot.Collections.Array;

public class Game : Node
{
    public const string Version = "Dev Build";
    public const int MaxHealth = 3;
    public const int MoveSpeed = 600;

    public bool IsPlaying = false;
    public string Map = "BigMap";
    public string UserName = "";
    public long UserId = 0;
}
