using Godot;
using Godot.Collections;

public class HUDManager : Control
{
    public void CreateHUD(Dictionary data)
    {
        Label label = new Label();
        label.Name = (string)data["Name"];
        label.Text = (string)data["Name"];
        label.Modulate = (Color)data["Modulate"];
        AddChild(label);
    }

    public void MoveHUDs(Array paddles)
    {
        foreach (Dictionary paddle in paddles)
        {
            string paddleName = (string)paddle["Name"];
            Label label = GetNodeOrNull<Label>(paddleName);
            if (label != null)
            {
                Vector2 paddlePos = (Vector2)paddle["Position"];
                Vector2 offset = new Vector2(label.RectSize.x / 2, 90);
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
        foreach (Label label in GetChildren())
        {
            label.QueueFree();
        }
    }
}
