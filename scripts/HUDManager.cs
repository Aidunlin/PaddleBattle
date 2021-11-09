using Godot;
using Godot.Collections;

public class HUDManager : Control
{
    public void CreateHUD(Dictionary data)
    {
        VBoxContainer hud = new VBoxContainer();
        hud.Name = (string)data["name"];
        hud.SizeFlagsHorizontal = (int)VBoxContainer.SizeFlags.ExpandFill;
        hud.Modulate = (Color)data["color"];
        hud.Alignment = BoxContainer.AlignMode.Center;
        hud.Set("custom_constants/separation", -8);
        AddChild(hud);

        Label label = new Label();
        label.Text = (string)data["name"];
        label.Align = Label.AlignEnum.Center;
        hud.AddChild(label);
    }

    public void MoveHUDs(Array paddles)
    {
        foreach (object paddle in paddles)
        {
            string paddleName = (string)((Dictionary)paddle)["name"];
            VBoxContainer hud = GetNode<VBoxContainer>(paddleName);
            Vector2 paddlePos = (Vector2)((Dictionary)paddle)["position"];
            Vector2 offset = new Vector2(hud.RectSize.x / 2, 90);
            hud.RectPosition = paddlePos - offset;
        }
    }

    public void RemoveHUD(string paddle)
    {
        GetNode(paddle).QueueFree();
    }

    public void Reset()
    {
        foreach (VBoxContainer hud in GetChildren())
        {
            hud.QueueFree();
        }
    }
}