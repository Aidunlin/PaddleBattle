using Godot;

public class Game : Node
{
    public const string Version = "Dev Build";
    public const int MaxHealth = 3;
    public const int MoveSpeed = 600;

    [Export] public bool IsPlaying = false;
    [Export] public string MapName = "BigMap";
    [Export] public string UserName = "";
    [Export] public long UserId = 0;

    public void Reset()
    {
        IsPlaying = false;
    }
}
