using Godot;
using Godot.Collections;

public class MenuMatch : VBoxContainer
{
    public Button MapButton;
    public Button StartButton;
    public Button BackButton;

    public override void _Ready()
    {
        MapButton = GetNode<Button>("Map");
        StartButton = GetNode<Button>("Start");
        BackButton = GetNode<Button>("Back");
    }
}
