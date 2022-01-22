using Godot;
using Godot.Collections;

public class MenuOptions : VBoxContainer
{
    public Button EndButton;
    public Button CloseButton;

    public override void _Ready()
    {
        EndButton = GetNode<Button>("End");
        CloseButton = GetNode<Button>("Close");
    }
}
