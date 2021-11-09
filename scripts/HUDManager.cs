using Godot;
using Godot.Collections;

public class HUDManager : Control
{
    public Dictionary HUDs = new Dictionary();

    public void CreateHUD(Dictionary data)
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

    public void MoveHUDs(Array paddles)
    {
        foreach (object paddle in paddles)
        {
            var paddleName = (string)((Dictionary)paddle)["name"];
            Vector2 offset = new Vector2(((VBoxContainer)HUDs[paddleName]).RectSize.x / 2, 90);
            Vector2 paddlePos = (Vector2)((Dictionary)paddle)["position"];
            ((VBoxContainer)HUDs[paddleName]).RectPosition = paddlePos - offset;
        }
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
