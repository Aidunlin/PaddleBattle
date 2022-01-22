using Godot;
using Godot.Collections;

public class MapManager : Node
{
    private Game _game;

    [Export] public Array<Dictionary> Maps { get; set; } = new Array<Dictionary>();
    [Export] public int SelectedMapIndex { get; set; } = 0;
    [Export] public Node2D MapNode { get; set; } = null;

    public string MapName {
        get {
            if (Maps.Count > SelectedMapIndex)
            {
                return (string)Maps[SelectedMapIndex]["Name"];
            }
            else
            {
                return "NO MAP";
            }   
        }
    }

    public override void _Ready()
    {
        _game = GetNode<Game>("/root/Game");
        
        GetMapsFromFolder();
    }

    public void GetMapsFromFolder()
    {
        Directory directory = new Directory();

        if (directory.Open("res://Scenes/Maps") == Error.Ok)
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
                    map.Add("Scene", GD.Load<PackedScene>("res://Scenes/Maps/" + fileName));
                    Maps.Add(map);
                }

                fileName = directory.GetNext();
            }
        }
    }

    public void LoadMap(string newMap, Color newColor)
    {
        foreach (Dictionary map in Maps)
        {
            if (((string)map["Name"]).Equals(newMap))
            {
                MapNode = ((PackedScene)map["Scene"]).Instance<Node2D>();
                MapNode.Modulate = newColor;
                AddChild(MapNode);
                return;
            }
        }
    }

    public string Switch()
    {
        if (SelectedMapIndex + 1 < Maps.Count)
        {
            SelectedMapIndex++;
        }
        else
        {
            SelectedMapIndex = 0;
        }

        return MapName;
    }

    public Vector2 GetCameraSpawn()
    {
        return MapNode?.GetNode<Node2D>("CameraSpawn")?.Position ?? Vector2.Zero;
    }

    public Array GetPaddleSpawns()
    {
        return MapNode?.GetNode("PaddleSpawns")?.GetChildren();
    }

    public Array GetBallSpawns()
    {
        return MapNode?.GetNode("BallSpawns")?.GetChildren();
    }

    public void Reset()
    {
        MapNode?.QueueFree();
        MapNode = null;
    }
}
