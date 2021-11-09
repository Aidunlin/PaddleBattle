using Godot;
using GColl = Godot.Collections;

public class HUDManager : Control
{
    public GColl.Dictionary<string, VBoxContainer> HUDs = new GColl.Dictionary<string, VBoxContainer>();

    public void CreateHUD(GColl.Dictionary data)
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

    public void MoveHUDs(GColl.Array paddles)
    {
        foreach (GColl.Dictionary paddle in paddles)
        {
            VBoxContainer hud = HUDs[(string)paddle["name"]];
            Vector2 offset = new Vector2(hud.RectSize.x / 2, 90);
            Vector2 paddlePos = (Vector2)paddle["position"];
            hud.RectPosition = paddlePos - offset;
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
