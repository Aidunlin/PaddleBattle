using Godot;
using Godot.Collections;

public class PaddleManager : Node
{
    public Game game;
    public DiscordManager discordManager;

    [Signal] public delegate void OptionsRequested();
    [Signal] public delegate void PaddleCreated();
    [Signal] public delegate void PaddleDamaged();
    [Signal] public delegate void PaddleDestroyed();
    [Signal] public delegate void PaddleRemoved();

    public PackedScene PaddleScene = (PackedScene)GD.Load("res://Scenes/Paddle.tscn");

    [Export] public Dictionary<string, int> InputList = new Dictionary<string, int>();
    [Export] public Array UsedInputs = new Array();
    [Export] public Array Spawns = new Array();

    public override void _Ready()
    {
        game = GetNode<Game>("/root/Game");
        discordManager = GetNode<DiscordManager>("/root/DiscordManager");
    }

    public bool InputListHasPad(int pad)
    {
        foreach (var item in InputList)
        {
            if (item.Value == pad)
            {
                return true;
            }
        }
        return false;
    }

    public override void _PhysicsProcess(float delta)
    {
        if (game.IsPlaying)
        {
            if (Input.IsKeyPressed((int)KeyList.Enter) && !InputListHasPad(-1))
            {
                CreatePaddleFromInput(-1);
            }
            foreach (int pad in Input.GetConnectedJoypads())
            {
                if (Input.IsJoyButtonPressed(pad, (int)JoystickList.Button0) && !InputListHasPad(pad))
                {
                    CreatePaddleFromInput(pad);
                }
            }
            if (Input.IsKeyPressed((int)KeyList.Escape) && UsedInputs.Contains(-1))
            {
                EmitSignal("OptionsRequested");
            }
            foreach (int pad in UsedInputs)
            {
                if (Input.IsJoyButtonPressed(pad, (int)JoystickList.Start))
                {
                    EmitSignal("OptionsRequested");
                }
            }
        }
    }

    public void CreatePaddleFromInput(int pad)
    {
        if (!UsedInputs.Contains(pad))
        {
            Dictionary newPaddle = new Dictionary();
            newPaddle.Add("Name", game.UserName);
            newPaddle.Add("Id", game.UserId.ToString());
            newPaddle.Add("Pad", pad);
            UsedInputs.Add(pad);
            if (discordManager.IsLobbyOwner())
            {
                CreatePaddle(newPaddle);
            }
            else
            {
                Dictionary paddleData = new Dictionary();
                paddleData.Add("PaddleData", newPaddle);
                discordManager.SendOwner(paddleData, true);
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
                paddleNode.Modulate = Color.FromHsv(GD.Randf(), (float)0.8, 1);
            }
            paddleNode.Connect("Damaged", this, "DamagePaddle", new Array() { newName });
            if (game.UserId == long.Parse((string)newPaddle["Id"]) && newPaddle.Contains("Pad"))
            {
                InputList.Add(newName, (int)newPaddle["Pad"]);
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
            if (discordManager.IsLobbyOwner())
            {
                Dictionary newData = GetPaddle(paddleNode);
                if (game.UserId != long.Parse((string)newPaddle["Id"]) && newPaddle.Contains("Pad"))
                {
                    newData["Pad"] = newPaddle["Pad"];
                }
                Dictionary paddleData = new Dictionary();
                paddleData.Add("PaddleData", newData);
                discordManager.SendAll(paddleData, true);
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
        if (!game.IsPlaying) return;
        for (int i = 0; i < newPaddles.Count; i++)
        {
            Dictionary newPaddle = (Dictionary)newPaddles[i];
            string paddleName = (string)newPaddle["Name"];
            Paddle paddleNode = GetNode<Paddle>(paddleName);
            if (discordManager.IsLobbyOwner())
            {
                if (game.UserId == long.Parse((string)newPaddle["Id"]))
                {
                    SetPaddleInputs(paddleName, GetPaddleInputs(paddleName));
                }
            }
            else
            {
                paddleNode.Position = (Vector2)newPaddle["Position"];
                paddleNode.Rotation = (float)newPaddle["Rotation"];
                if (game.UserId == long.Parse((string)newPaddle["Id"]))
                {
                    Dictionary inputData = new Dictionary();
                    inputData.Add("Paddle", paddleName);
                    inputData.Add("Inputs", GetPaddleInputs(paddleName));
                    discordManager.SendOwner(inputData, false);
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

    public int GetKey(int key)
    {
        return Input.IsKeyPressed(key) ? 1 : 0;
    }

    public float GetAxis(int pad, int axis)
    {
        return Input.GetJoyAxis(pad, axis);
    }

    public Dictionary GetPaddleInputs(string paddleName)
    {
        Dictionary inputs = new Dictionary();
        inputs.Add("Velocity", new Vector2());
        inputs.Add("Rotation", (float)0.0);
        inputs.Add("Dash", false);
        if (!InputList.ContainsKey(paddleName) || !game.IsPlaying)
        {
            return inputs;
        }
        int pad = InputList[paddleName];
        if (pad == -1)
        {
            inputs["Velocity"] = new Vector2(
                GetKey((int)KeyList.D) - GetKey((int)KeyList.A),
                GetKey((int)KeyList.S) - GetKey((int)KeyList.W)
            ).Normalized() * Game.MoveSpeed;
            inputs["Dash"] = Input.IsKeyPressed((int)KeyList.Shift);
            inputs["Rotation"] = Mathf.Deg2Rad(
                (GetKey((int)KeyList.Period) - GetKey((int)KeyList.Comma)) * 4
            );
        }
        else
        {
            Vector2 leftStick = new Vector2(
                GetAxis(pad, (int)JoystickList.AnalogLx),
                GetAxis(pad, (int)JoystickList.AnalogLy)
            );
            Vector2 rightStick = new Vector2(
                GetAxis(pad, (int)JoystickList.AnalogRx),
                GetAxis(pad, (int)JoystickList.AnalogRy)
            );
            if (leftStick.Length() > 0.2)
            {
                inputs["Velocity"] = leftStick * Game.MoveSpeed;
            }
            inputs["Dash"] = Input.IsJoyButtonPressed(pad, (int)JoystickList.L2);
            if (rightStick.Length() > 0.7)
            {
                Paddle paddleNode = GetNode<Paddle>(paddleName);
                inputs["Rotation"] = paddleNode.GetAngleTo(paddleNode.Position + rightStick) * 0.1;
            }
        }
        return inputs;
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
            EmitSignal("PaddleDestroyed", paddleNode.Health + " was destroyed");
            if (discordManager.IsLobbyOwner())
            {
                paddleNode.Position = ((Node2D)Spawns[paddleNode.GetIndex()]).Position;
                paddleNode.Rotation = ((Node2D)Spawns[paddleNode.GetIndex()]).Rotation;
            }
            paddleNode.GetNode<Sprite>("Crack").Modulate = new Color(1, 1, 1, 0);
            paddleNode.Health = paddleNode.MaxHealth;
        }
        if (discordManager.IsLobbyOwner())
        {
            Dictionary paddleData = new Dictionary();
            paddleData.Add("Paddle", paddleName);
            discordManager.SendAll(paddleData, true);
        }
    }

    public void Reset()
    {
        InputList.Clear();
        UsedInputs.Clear();
        foreach (Node paddle in GetChildren())
        {
            paddle.QueueFree();
        }
        Spawns.Clear();
    }
}
