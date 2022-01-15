using Godot;
using Godot.Collections;

public class PaddleManager : Node
{
    private Game _game;
    private DiscordManager _discordManager;
    private InputManager _inputManager;

    [Signal] public delegate void PaddleCreated();
    [Signal] public delegate void PaddleDamaged();
    [Signal] public delegate void PaddleDestroyed();
    [Signal] public delegate void PaddleRemoved();

    public PackedScene PaddleScene = (PackedScene)GD.Load("res://Scenes/Paddle.tscn");

    [Export] public Array Spawns = new Array();

    public override void _Ready()
    {
        _game = GetNode<Game>("/root/Game");
        _discordManager = GetNode<DiscordManager>("/root/DiscordManager");
        _inputManager = GetNode<InputManager>("/root/InputManager");
    }

    public void CreatePaddleFromInput(int pad)
    {
        if (!_inputManager.UsedInputs.Contains(pad))
        {
            Dictionary newPaddle = new Dictionary();
            newPaddle.Add("Name", _game.Username);
            newPaddle.Add("Id", _game.UserId.ToString());
            newPaddle.Add("Pad", pad);
            _inputManager.UsedInputs.Add(pad);

            if (_discordManager.IsLobbyOwner())
            {
                CreatePaddle(newPaddle);
            }
            else
            {
                Dictionary paddleData = new Dictionary();
                paddleData.Add("PaddleData", newPaddle);
                _discordManager.SendOwner(paddleData, true);
            }
        }
    }

    public T DictCoalesce<T>(Dictionary dict, string key, T defaultValue)
    {
        if (dict.Contains(key))
        {
            return (T)dict[key];
        }
        else
        {
            return defaultValue;
        }
    }

    public void CreatePaddle(Dictionary newPaddle)
    {
        int paddleCount = GetChildCount();

        if (paddleCount < Spawns.Count)
        {
            Paddle paddleNode = PaddleScene.Instance<Paddle>();
            int nameCount = 1;

            foreach (Paddle paddle in GetChildren())
            {
                if (paddle.Name.Contains((string)newPaddle["Name"]))
                {
                    nameCount++;
                }
            }

            string newName = (string)newPaddle["Name"];

            if (nameCount > 1)
            {
                newName += nameCount.ToString();
            }

            paddleNode.Name = newName;
            paddleNode.Id = (string)newPaddle["Id"];
            paddleNode.Pad = (int)newPaddle["Pad"];
            paddleNode.Position = DictCoalesce<Vector2>(newPaddle, "Position", ((Node2D)Spawns[paddleCount]).Position);
            paddleNode.Rotation = DictCoalesce<float>(newPaddle, "Rotation", ((Node2D)Spawns[paddleCount]).Rotation);
            paddleNode.Modulate = DictCoalesce<Color>(newPaddle, "Modulate", Color.FromHsv(GD.Randf(), 1, 1));
            paddleNode.MaxHealth = DictCoalesce<int>(newPaddle, "MaxHealth", Game.MaxHealth);
            paddleNode.Health = DictCoalesce<int>(newPaddle, "Health", paddleNode.MaxHealth);

            if (paddleNode.Health < paddleNode.MaxHealth)
            {
                double crackOpacity = 1.0 - (paddleNode.Health / (double)paddleNode.MaxHealth);
                crackOpacity *= 0.7;

                if (paddleNode.Health == 1)
                {
                    crackOpacity = 1;
                }

                paddleNode.GetNode<Sprite>("Crack").Modulate = new Color(1, 1, 1, (float)crackOpacity);
            }

            bool paddleIsLocal = _game.UserId == long.Parse(paddleNode.Id);

            if (paddleIsLocal && newPaddle.Contains("Pad"))
            {
                _inputManager.InputList.Add(paddleNode.Name, paddleNode.Pad);
            }

            paddleNode.Connect("Damaged", this, "DamagePaddle", new Array() { paddleNode.Name });
            EmitSignal("PaddleCreated", GetPaddleData(paddleNode));

            if (_discordManager.IsLobbyOwner())
            {
                Dictionary paddleData = new Dictionary();
                paddleData.Add("PaddleData", GetPaddleData(paddleNode));
                _discordManager.SendAll(paddleData, true);
            }

            AddChild(paddleNode);
        }
    }

    public Dictionary GetPaddleData(Paddle paddle)
    {
        Dictionary paddleDict = new Dictionary();
        paddleDict["Id"] = paddle.Id;
        paddleDict["Name"] = paddle.Name;
        paddleDict["Pad"] = paddle.Pad;
        paddleDict["Position"] = paddle.Position;
        paddleDict["Rotation"] = paddle.Rotation;
        paddleDict["Modulate"] = paddle.Modulate;
        paddleDict["Health"] = paddle.Health;
        paddleDict["MaxHealth"] = paddle.MaxHealth;
        return paddleDict;
    }

    public Array GetPaddles()
    {
        Array paddles = new Array();

        foreach (Paddle paddle in GetChildren())
        {
            paddles.Add(GetPaddleData(paddle));
        }

        return paddles;
    }

    public void UpdatePaddles(Array newPaddles)
    {
        if (!_game.IsPlaying) return;

        foreach (Dictionary paddle in newPaddles)
        {
            string paddleName = (string)paddle["Name"];
            Paddle paddleNode = GetNodeOrNull<Paddle>(paddleName);
            
            if (paddleNode != null)
            {
                bool paddleIsLocal = _game.UserId == long.Parse((string)paddle["Id"]);

                if (_discordManager.IsLobbyOwner())
                {
                    if (paddleIsLocal)
                    {
                        SetPaddleInputs(paddleName, _inputManager.GetPaddleInputs(paddleNode));
                    }
                }
                else
                {
                    paddleNode.Position = (Vector2)paddle["Position"];
                    paddleNode.Rotation = (float)paddle["Rotation"];

                    if (paddleIsLocal)
                    {
                        Dictionary inputData = new Dictionary();
                        inputData.Add("Paddle", paddleName);
                        inputData.Add("Inputs", _inputManager.GetPaddleInputs(paddleNode));
                        _discordManager.SendOwner(inputData, false);
                    }
                }
            }
        }
    }

    public void RemovePaddles(long id)
    {
        foreach (Paddle paddle in GetChildren())
        {
            if (id == long.Parse(paddle.Id))
            {
                EmitSignal("PaddleRemoved", paddle.Name);
                GetNode(paddle.Name).QueueFree();
            }
        }
    }

    public void SetPaddleInputs(string paddle, Dictionary inputs)
    {
        GetNodeOrNull<Paddle>(paddle)?.SetInputs(inputs);
    }

    public void DamagePaddle(string paddleName)
    {
        Paddle paddleNode = GetNode<Paddle>(paddleName);
        paddleNode.Health -= 1;
        double crackOpacity = 1.0 - (paddleNode.Health / (double)paddleNode.MaxHealth);
        crackOpacity *= 0.7;

        if (paddleNode.Health == 1)
        {
            crackOpacity = 1;
        }

        paddleNode.GetNode<Sprite>("Crack").Modulate = new Color(1, 1, 1, (float)crackOpacity);

        if (paddleNode.Health < 1)
        {
            EmitSignal("PaddleDestroyed", paddleNode.Name + " was destroyed");

            if (_discordManager.IsLobbyOwner())
            {
                paddleNode.Position = ((Node2D)Spawns[paddleNode.GetIndex()]).Position;
                paddleNode.Rotation = ((Node2D)Spawns[paddleNode.GetIndex()]).Rotation;
            }

            paddleNode.GetNode<Sprite>("Crack").Modulate = new Color(1, 1, 1, 0);
            paddleNode.Health = paddleNode.MaxHealth;
        }

        if (_discordManager.IsLobbyOwner())
        {
            Dictionary paddleData = new Dictionary();
            paddleData.Add("Paddle", paddleName);
            _discordManager.SendAll(paddleData, true);
        }
    }

    public void Reset()
    {
        foreach (Node paddle in GetChildren())
        {
            paddle.QueueFree();
        }

        Spawns.Clear();
    }
}
