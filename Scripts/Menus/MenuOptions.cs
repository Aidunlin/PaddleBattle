using Godot;
using Godot.Collections;

public class MenuOptions : VBoxContainer
{
    public Button EndButton { get; set; }
    public Button CloseButton { get; set; }

    public override void _Ready()
    {
        EndButton = GetNode<Button>("End");
        CloseButton = GetNode<Button>("Close");
    }
}
