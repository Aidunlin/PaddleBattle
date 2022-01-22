using Godot;
using Godot.Collections;

public class MenuMatch : VBoxContainer
{
    public Button MapButton { get; set; }
    public Button StartButton { get; set; }
    public Button BackButton { get; set; }

    public override void _Ready()
    {
        MapButton = GetNode<Button>("Map");
        StartButton = GetNode<Button>("Start");
        BackButton = GetNode<Button>("Back");
    }
}
