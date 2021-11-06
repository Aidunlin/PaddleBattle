using Godot;
using System;

public class HUDManager : Control
{
    public Godot.Collections.Dictionary<string, VBoxContainer> HUDs = new Godot.Collections.Dictionary<string, VBoxContainer>();

    public void CreateHUD(Godot.Collections.Dictionary data)
    {
        VBoxContainer hud = new VBoxContainer();
        hud.Name = (string)data["name"];
        hud.SizeFlagsHorizontal = (int)VBoxContainer.SizeFlags.ExpandFill;
        hud.Modulate = (Color)data["color"];
        hud.Alignment = BoxContainer.AlignMode.Center;
        hud.Set("custom_constants/separation", -8);
        Label label = new Label();
        label.Text = (string)data["name"];
        label.Align = Label.AlignEnum.Center;
        hud.AddChild(label);
        AddChild(hud);
        HUDs.Add(hud.Name, hud);
    }

    public void MoveHUDs(Godot.Collections.Dictionary<string, Godot.Collections.Dictionary> paddles)
    {
        foreach (var paddleName in paddles.Keys)
        {
            VBoxContainer hud = HUDs[(string)paddleName];
            Vector2 offset = new Vector2(hud.RectSize.x / 2, 90);
            Vector2 paddlePos = (Vector2)paddles[(string)paddleName]["position"];
            hud.RectPosition = paddlePos - offset;
        }
        // foreach (var paddle in paddles)
        // {
        //     VBoxContainer hud = HUDs[paddle.Key];
        //     Vector2 offset = new Vector2(hud.RectSize.x / 2, 90);
        //     Vector2 paddlePos = paddle.Value.Position;
        //     hud.RectPosition = paddlePos - offset;
        // }
    }

    public void RemoveHUD(string paddle)
    {
        GetNode(paddle).QueueFree();
        HUDs.Remove(paddle);
    }

    public void Reset()
    {
        foreach (VBoxContainer hud in GetChildren())
        {
            hud.QueueFree();
        }
        HUDs.Clear();
    }
}
