using Godot;
using System;

public class Camera : Camera2D
{
    public Vector2 Spawn = Vector2.Zero;

    public void MoveAndZoom(Godot.Collections.Array<Node2D> paddles)
    {
        Vector2 newZoom = Vector2.One;
        if (paddles.Count > 0)
        {
            Vector2 average = Vector2.Zero;
            float maxX = float.MinValue;
            float MinX = float.MaxValue;
            float maxY = float.MinValue;
            float MinY = float.MaxValue;
            foreach (var paddle in paddles)
            {
                average += paddle.Position;
                maxX = Math.Max(paddle.Position.x, maxX);
                MinX = Math.Min(paddle.Position.x, MinX);
                maxY = Math.Max(paddle.Position.y, maxY);
                MinY = Math.Min(paddle.Position.y, MinY);
            }
            average /= paddles.Count;
            float largestX = 2 * Math.Max(maxX - average.x, average.x - MinX);
            float largestY = 2 * Math.Max(maxY - average.y, average.y - MinY);
            float marginX = OS.WindowSize.x * 2 / 3;
            float marginY = OS.WindowSize.y * 2 / 3;
            newZoom.x = (largestX + marginX) / OS.WindowSize.x;
            newZoom.y = (largestY + marginY) / OS.WindowSize.y;
            float largestZoom = Math.Max(newZoom.x, newZoom.y);
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
        if (newSpawn != null)
        {
            Spawn = newSpawn;
        }
        Position = Spawn;
    }
}
