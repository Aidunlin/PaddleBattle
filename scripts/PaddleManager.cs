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
    [Export] public Array Paddles = new Array();
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
            if (newPaddle.Contains("Position") && newPaddle.Contains("Rotation"))
            {
                paddleNode.Position = (Vector2)newPaddle["Position"];
                paddleNode.Rotation = (float)newPaddle["Rotation"];
            }
            else
            {
                paddleNode.Position = ((Node2D)Spawns[paddleCount]).Position;
                paddleNode.Rotation = ((Node2D)Spawns[paddleCount]).Rotation;
            }
            if (newPaddle.Contains("Color"))
            {
                paddleNode.Modulate = (Color)newPaddle["Color"];
            }
            else
            {
                paddleNode.Modulate = Color.FromHsv(GD.Randf(), (float)0.8, 1);
            }
            paddleNode.Connect("Damaged", this, "DamagePaddle", new Array() { newName });
            if (game.UserId == long.Parse((string)newPaddle["Id"]) && newPaddle.Contains("Pad"))
            {
                InputList.Add(newName, (int)newPaddle["Pad"]);
            }
            Dictionary paddleToAddToArray = new Dictionary();
            paddleToAddToArray["Id"] = newPaddle["Id"];
            paddleToAddToArray["Name"] = newName;
            paddleToAddToArray["Position"] = paddleNode.Position;
            paddleToAddToArray["Rotation"] = paddleNode.Rotation;
            paddleToAddToArray["Color"] = paddleNode.Modulate;
            if (newPaddle.Contains("Health"))
            {
                paddleToAddToArray["Health"] = newPaddle["Health"];
                float crackOpacity = (float)1.0 - ((int)newPaddle["Health"] / (float)Game.MaxHealth);
                crackOpacity *= (float)0.7;
                if ((int)newPaddle["Health"] == 1)
                {
                    crackOpacity = 1;
                }
                paddleNode.GetNode<Sprite>("Crack").Modulate = new Color(1, 1, 1, crackOpacity);
            }
            else
            {
                paddleToAddToArray["Health"] = Game.MaxHealth;
            }
            EmitSignal("PaddleCreated", paddleToAddToArray);
            if (discordManager.IsLobbyOwner())
            {
                Dictionary newData = paddleToAddToArray.Duplicate(true);
                if (game.UserId != long.Parse((string)newPaddle["Id"]) && newPaddle.Contains("Pad"))
                {
                    newData["Pad"] = newPaddle["Pad"];
                }
                Dictionary paddleData = new Dictionary();
                paddleData.Add("PaddleData", newData);
                discordManager.SendAll(paddleData, true);
            }
            Paddles.Add(paddleToAddToArray);
            AddChild(paddleNode);
        }
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
                ((Dictionary)Paddles[i])["Position"] = paddleNode.Position;
                ((Dictionary)Paddles[i])["Rotation"] = paddleNode.Rotation;
                if (game.UserId == long.Parse((string)newPaddle["Id"]))
                {
                    SetPaddleInputs(paddleName, GetPaddleInputs(paddleName));
                }
            }
            else
            {
                ((Dictionary)Paddles[i])["Position"] = newPaddle["Position"];
                ((Dictionary)Paddles[i])["Rotation"] = newPaddle["Rotation"];
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
        foreach (Dictionary paddle in Paddles)
        {
            if (id == long.Parse((string)paddle["Id"]))
            {
                Paddles.Remove(paddle);
                GetNode((string)paddle["Name"]).QueueFree();
                EmitSignal("PaddleRemoved", (string)paddle["Name"]);
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

    public Dictionary GetPaddleInputs(string paddle)
    {
        Dictionary inputs = new Dictionary();
        inputs.Add("Velocity", new Vector2());
        inputs.Add("Rotation", (float)0.0);
        inputs.Add("Dash", false);
        if (!InputList.ContainsKey(paddle) || !game.IsPlaying) return inputs;
        int pad = InputList[paddle];
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
                Paddle paddleNode = GetNode<Paddle>(paddle);
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
        int paddleIndex = 0;
        for (; paddleIndex < Paddles.Count; paddleIndex++)
        {
            Dictionary testPaddle = (Dictionary)Paddles[paddleIndex];
            if (paddleName == (string)testPaddle["Name"])
            {
                break;
            }
        }
        Dictionary thing = (Dictionary)Paddles[paddleIndex];
        Paddle paddleNode = GetNode<Paddle>(paddleName);
        thing["Health"] = (int)thing["Health"] - 1;
        float crackOpacity = (float)1.0 - ((int)thing["Health"] / (float)Game.MaxHealth);
        crackOpacity *= (float)0.7;
        if ((int)thing["Health"] == 1)
        {
            crackOpacity = 1;
        }
        paddleNode.GetNode<Sprite>("Crack").Modulate = new Color(1, 1, 1, crackOpacity);
        if ((int)thing["Health"] < 1)
        {
            EmitSignal("PaddleDestroyed", thing["Name"] + " was destroyed", false);
            if (discordManager.IsLobbyOwner())
            {
                paddleNode.Position = ((Node2D)Spawns[paddleNode.GetIndex()]).Position;
                paddleNode.Rotation = ((Node2D)Spawns[paddleNode.GetIndex()]).Rotation;
            }
            paddleNode.GetNode<Sprite>("Crack").Modulate = new Color(1, 1, 1, 0);
            thing["Health"] = Game.MaxHealth;
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
        Paddles.Clear();
        Spawns.Clear();
    }
}
