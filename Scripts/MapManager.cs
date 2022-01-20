using Godot;
using Godot.Collections;

public class MapManager : Node
{
    private Game _game;

    [Export] public Array<Dictionary> Maps = new Array<Dictionary>();
    [Export] public Node2D Map = null;
    [Export] public Color MapColor = new Color();
    [Export] public string MapName = "NO MAP";

    public override void _Ready()
    {
        _game = GetNode<Game>("/root/Game");
        
        GetMapsFromFolder();
    }

    public void GetMapsFromFolder()
    {
        Directory directory = new Directory();

        if (directory.Open("res://Maps") == Error.Ok)
        {
            directory.ListDirBegin();
            string fileName = directory.GetNext();

            while (fileName != "")
            {
                if (!directory.CurrentIsDir() && fileName.EndsWith(".tscn"))
                {
                    string mapName = fileName.ReplaceN(".tscn", "");
                    Dictionary map = new Dictionary();
                    map.Add("Name", mapName);
                    map.Add("Scene", GD.Load<PackedScene>("res://Maps/" + fileName));
                    Maps.Add(map);
                }

                fileName = directory.GetNext();
            }
            
            MapName = (string)Maps[0]["Name"];
        }
    }

    public void LoadMap(string newMap, Color newColor)
    {
        MapColor = newColor;

        foreach (Dictionary map in Maps)
        {
            if (((string)map["Name"]).Equals(newMap))
            {
                Map = ((PackedScene)map["Scene"]).Instance<Node2D>();
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
            if ((string)(Maps[mapIndex])["Name"] == MapName)
            {
                break;
            }
        }

        int newIndex = 0;

        if (mapIndex + 1 < Maps.Count)
        {
            newIndex = mapIndex + 1;
        }

        string newMapName = (string)(Maps[newIndex])["Name"];
        MapName = newMapName;
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
