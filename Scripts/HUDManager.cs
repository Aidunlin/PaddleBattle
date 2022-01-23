using Godot;
using Godot.Collections;

public class HUDManager : Control
{
    public void CreateHUD(Dictionary data)
    {
        var label = new Label();
        label.Name = (string)data["Name"];
        label.Text = (string)data["Name"];
        label.Modulate = (Color)data["Modulate"];
        AddChild(label);
    }

    public void MoveHUDs(Array paddles)
    {
        foreach (Dictionary paddle in paddles)
        {
            var paddleName = (string)paddle["Name"];
            var label = GetNodeOrNull<Label>(paddleName);
            if (label != null)
            {
                var paddlePos = (Vector2)paddle["Position"];
                var offset = new Vector2(label.RectSize.x / 2, 90);
                label.RectPosition = paddlePos - offset;
            }
        }
    }

    public void RemoveHUD(string paddleName)
    {
        GetNodeOrNull(paddleName)?.QueueFree();
    }

    public void Reset()
    {
        foreach (Node label in GetChildren())
        {
            label.QueueFree();
        }
    }
}
