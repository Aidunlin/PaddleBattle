using Godot;
using Godot.Collections;

public class Camera : Camera2D
{
    [Export] public Vector2 Spawn { get; set; } = new Vector2();

    public void MoveAndZoom(Array paddles)
    {
        var newZoom = Vector2.One;

        if (paddles.Count > 0)
        {
            var average = new Vector2();
            var maxX = float.MinValue;
            var MinX = float.MaxValue;
            var maxY = float.MinValue;
            var MinY = float.MaxValue;

            foreach (Node2D paddle in paddles)
            {
                average += paddle.Position;
                maxX = System.Math.Max(paddle.Position.x, maxX);
                MinX = System.Math.Min(paddle.Position.x, MinX);
                maxY = System.Math.Max(paddle.Position.y, maxY);
                MinY = System.Math.Min(paddle.Position.y, MinY);
            }

            average /= paddles.Count;
            var largestX = 2 * System.Math.Max(maxX - average.x, average.x - MinX);
            var largestY = 2 * System.Math.Max(maxY - average.y, average.y - MinY);
            var marginX = OS.WindowSize.x * 2 / 3;
            var marginY = OS.WindowSize.y * 2 / 3;
            newZoom.x = (largestX + marginX) / OS.WindowSize.x;
            newZoom.y = (largestY + marginY) / OS.WindowSize.y;
            var largestZoom = System.Math.Max(newZoom.x, newZoom.y);
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
