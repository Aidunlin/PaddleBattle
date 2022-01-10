using Godot;
using Godot.Collections;

public class HUDManager : Control
{
    public void CreateHUD(Dictionary data)
    {
        VBoxContainer hud = new VBoxContainer();
        hud.Name = (string)data["Name"];
        hud.SizeFlagsHorizontal = (int)VBoxContainer.SizeFlags.ExpandFill;
        hud.Modulate = (Color)data["Modulate"];
        hud.Alignment = BoxContainer.AlignMode.Center;
        hud.Set("custom_constants/separation", -8);
        AddChild(hud);

        Label label = new Label();
        label.Text = (string)data["Name"];
        label.Align = Label.AlignEnum.Center;
        hud.AddChild(label);
    }

    public void MoveHUDs(Array paddles)
    {
        foreach (Dictionary paddle in paddles)
        {
            string paddleName = (string)paddle["Name"];
            VBoxContainer hud = GetNode<VBoxContainer>(paddleName);
            Vector2 paddlePos = (Vector2)paddle["Position"];
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
