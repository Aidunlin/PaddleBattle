using Godot;
using Godot.Collections;

public class MapManager : Node
{
    public Array Maps = new Array();

    public Node2D Map = null;
    public Color MapColor = new Color();

    public Game game;

    public override void _Ready()
    {
        game = GetNode<Game>("/root/Game");

        Dictionary bigMapDict = new Dictionary();
        bigMapDict.Add("name", "BigMap");
        bigMapDict.Add("scene", (PackedScene)GD.Load("res://Maps/BigMap.tscn"));
        Maps.Add(bigMapDict);

        Dictionary smallMapDict = new Dictionary();
        smallMapDict.Add("name", "SmallMap");
        smallMapDict.Add("scene", (PackedScene)GD.Load("res://Maps/SmallMap.tscn"));
        Maps.Add(smallMapDict);
    }

    public void LoadMap(string newMap, Color newColor)
    {
        MapColor = newColor;
        foreach (Dictionary map in Maps)
        {
            if (((string)map["name"]).Equals(newMap))
            {
                Map = ((PackedScene)map["scene"]).Instance<Node2D>();
                Map.Modulate = newColor;
                AddChild(Map);
                return;
            }
        }
    }

    public string Switch()
    {
        int mapIndex = 0;
        for (; mapIndex < Maps.Count; mapIndex++)
        {
            if ((string)((Dictionary)Maps[mapIndex])["name"] == game.Map)
            {
                break;
            }
        }
        int newIndex = 0;
        if (mapIndex + 1 != Maps.Count)
        {
            newIndex = mapIndex + 1;
        }
        string newMapName = (string)((Dictionary)Maps[mapIndex])["name"];
        game.Map = newMapName;
        return newMapName;
    }

    public Vector2 GetCameraSpawn()
    {
        return Map.GetNode<Node2D>("CameraSpawn").Position;
    }

    public Array GetPaddleSpawns()
    {
        return Map.GetNode("PaddleSpawns").GetChildren();
    }

    public Array GetBallSpawns()
    {
        return Map.GetNode("BallSpawns").GetChildren();
    }

    public void Reset()
    {
        if (Map != null)
        {
            Map.QueueFree();
            Map = null;
        }
    }
}
