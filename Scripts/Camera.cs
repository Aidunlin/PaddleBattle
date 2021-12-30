using Godot;
using Godot.Collections;

public class Camera : Camera2D
{
    [Export] public Vector2 Spawn = new Vector2();

    public void MoveAndZoom(Array paddles)
    {
        Vector2 newZoom = Vector2.One;
        if (paddles.Count > 0)
        {
            Vector2 average = new Vector2();
            float maxX = float.MinValue;
            float MinX = float.MaxValue;
            float maxY = float.MinValue;
            float MinY = float.MaxValue;
            foreach (Node2D paddle in paddles)
            {
                average += paddle.Position;
                maxX = System.Math.Max(paddle.Position.x, maxX);
                MinX = System.Math.Min(paddle.Position.x, MinX);
                maxY = System.Math.Max(paddle.Position.y, maxY);
                MinY = System.Math.Min(paddle.Position.y, MinY);
            }
            average /= paddles.Count;
            float largestX = 2 * System.Math.Max(maxX - average.x, average.x - MinX);
            float largestY = 2 * System.Math.Max(maxY - average.y, average.y - MinY);
            float marginX = OS.WindowSize.x * 2 / 3;
            float marginY = OS.WindowSize.y * 2 / 3;
            newZoom.x = (largestX + marginX) / OS.WindowSize.x;
            newZoom.y = (largestY + marginY) / OS.WindowSize.y;
            float largestZoom = System.Math.Max(newZoom.x, newZoom.y);
            newZoom = new Vector2(largestZoom, largestZoom);
            if (newZoom < Vector2.One)
            {
                newZoom = Vector2.One;
            }
            Position = average;
        }
        Zoom = Zoom.LinearInterpolate(newZoom, (float)0.05);
    }

    public void Reset(Vector2 newSpawn)
    {
        Spawn = newSpawn;
        Position = newSpawn;
    }
}
