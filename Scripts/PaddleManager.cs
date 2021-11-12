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
            newPaddle.Add("Name", _game.UserName);
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
            if (newPaddle.Contains("Position"))
            {
                paddleNode.Position = (Vector2)newPaddle["Position"];
            }
            else
            {
                paddleNode.Position = ((Node2D)Spawns[paddleCount]).Position;
            }
            if (newPaddle.Contains("Rotation"))
            {
                paddleNode.Rotation = (float)newPaddle["Rotation"];
            }
            else
            {
                paddleNode.Rotation = ((Node2D)Spawns[paddleCount]).Rotation;
            }
            if (newPaddle.Contains("Modulate"))
            {
                paddleNode.Modulate = (Color)newPaddle["Modulate"];
            }
            else
            {
                paddleNode.Modulate = Color.FromHsv(GD.Randf(), 1, 1);
            }
            paddleNode.Connect("Damaged", this, "DamagePaddle", new Array() { newName });
            if (_game.UserId == long.Parse((string)newPaddle["Id"]) && newPaddle.Contains("Pad"))
            {
                _inputManager.InputList.Add(newName, (int)newPaddle["Pad"]);
                paddleNode.Pad = (int)newPaddle["Pad"];
            }
            if (newPaddle.Contains("MaxHealth"))
            {
                paddleNode.MaxHealth = (int)newPaddle["MaxHealth"];
            }
            else
            {
                paddleNode.MaxHealth = Game.MaxHealth;
            }
            if (newPaddle.Contains("Health"))
            {
                paddleNode.Health = (int)newPaddle["Health"];
                double crackOpacity = 1.0 - ((int)newPaddle["Health"] / (double)paddleNode.MaxHealth);
                crackOpacity *= 0.7;
                if ((int)newPaddle["Health"] == 1)
                {
                    crackOpacity = 1;
                }
                paddleNode.GetNode<Sprite>("Crack").Modulate = new Color(1, 1, 1, (float)crackOpacity);
            }
            else
            {
                paddleNode.Health = paddleNode.MaxHealth;
            }
            EmitSignal("PaddleCreated", GetPaddle(paddleNode));
            if (_discordManager.IsLobbyOwner())
            {
                Dictionary newData = GetPaddle(paddleNode);
                if (_game.UserId != long.Parse((string)newPaddle["Id"]) && newPaddle.Contains("Pad"))
                {
                    newData["Pad"] = newPaddle["Pad"];
                }
                Dictionary paddleData = new Dictionary();
                paddleData.Add("PaddleData", newData);
                _discordManager.SendAll(paddleData, true);
            }
            AddChild(paddleNode);
        }
    }

    public Dictionary GetPaddle(Paddle paddle)
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
            paddles.Add(GetPaddle(paddle));
        }
        return paddles;
    }

    public void UpdatePaddles(Array newPaddles)
    {
        if (!_game.IsPlaying) return;
        for (int i = 0; i < newPaddles.Count; i++)
        {
            Dictionary newPaddle = (Dictionary)newPaddles[i];
            string paddleName = (string)newPaddle["Name"];
            Paddle paddleNode = GetNode<Paddle>(paddleName);
            if (_discordManager.IsLobbyOwner())
            {
                if (_game.UserId == long.Parse((string)newPaddle["Id"]))
                {
                    SetPaddleInputs(paddleName, _inputManager.GetPaddleInputs(paddleNode));
                }
            }
            else
            {
                paddleNode.Position = (Vector2)newPaddle["Position"];
                paddleNode.Rotation = (float)newPaddle["Rotation"];
                if (_game.UserId == long.Parse((string)newPaddle["Id"]))
                {
                    Dictionary inputData = new Dictionary();
                    inputData.Add("Paddle", paddleName);
                    inputData.Add("Inputs", _inputManager.GetPaddleInputs(paddleNode));
                    _discordManager.SendOwner(inputData, false);
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
