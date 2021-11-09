using Godot;
using GColl = Godot.Collections;

public class PaddleManager : Node
{
    [Signal] public delegate void OptionsRequested();
    [Signal] public delegate void PaddleCreated();
    [Signal] public delegate void PaddleDamaged();
    [Signal] public delegate void PaddleDestroyed();
    [Signal] public delegate void PaddleRemoved();

    public PackedScene PaddleScene = (PackedScene)GD.Load("res://scenes/paddle.tscn");

    public GColl.Dictionary<string, int> InputList = new GColl.Dictionary<string, int>();
    public GColl.Array UsedInputs = new GColl.Array();
    public GColl.Array Paddles = new GColl.Array();
    public GColl.Array Spawns = new GColl.Array();

    public Game game;
    public DiscordManager discordManager;

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
            GColl.Dictionary newPaddle = new GColl.Dictionary();
            newPaddle.Add("name", game.UserName);
            newPaddle.Add("id", game.UserId.ToString());
            newPaddle.Add("pad", pad);
            newPaddle.Add("has_pad", true);
            newPaddle.Add("already_exists", false);
            UsedInputs.Add(pad);
            if (discordManager.IsLobbyOwner())
            {
                CreatePaddle(newPaddle);
            }
            else
            {
                GColl.Dictionary paddleData = new GColl.Dictionary();
                paddleData.Add("paddle_data", newPaddle);
                discordManager.SendOwner(paddleData, true);
            }
        }
    }

    public void CreatePaddle(GColl.Dictionary newPaddle)
    {
        int paddleCount = GetChildCount();
        if (paddleCount < Spawns.Count)
        {
            Paddle paddleNode = PaddleScene.Instance<Paddle>();
            int nameCount = 1;
            foreach (Paddle paddle in GetChildren())
            {
                if (paddle.Name.Contains((string)newPaddle["name"]))
                {
                    nameCount++;
                }
            }
            string newName = (string)newPaddle["name"];
            if (nameCount > 1)
            {
                newName += nameCount.ToString();
            }
            paddleNode.Name = newName;
            if ((bool)newPaddle["already_exists"])
            {
                paddleNode.Position = (Vector2)newPaddle["position"];
                paddleNode.Rotation = (float)newPaddle["rotation"];
            }
            else
            {
                paddleNode.Position = ((Node2D)Spawns[paddleCount]).Position;
                paddleNode.Rotation = ((Node2D)Spawns[paddleCount]).Rotation;
            }
            if ((bool)newPaddle["already_exists"])
            {
                paddleNode.Modulate = (Color)newPaddle["color"];
            }
            else
            {
                paddleNode.Modulate = Color.FromHsv(GD.Randf(), (float)0.8, 1);
            }
            paddleNode.Connect("Damaged", this, "DamagePaddle", new GColl.Array(){newName});
            if (game.UserId == long.Parse((string)newPaddle["id"]) && (bool)newPaddle["has_pad"])
            {
                InputList.Add(newName, (int)newPaddle["pad"]);
            }
            GColl.Dictionary paddleToAddToArray = new GColl.Dictionary();
            paddleToAddToArray["id"]  = newPaddle["id"];
            paddleToAddToArray["name"]  = newName;
            paddleToAddToArray["position"]  = paddleNode.Position;
            paddleToAddToArray["rotation"]  = paddleNode.Rotation;
            paddleToAddToArray["color"]  = paddleNode.Modulate;
            if ((bool)newPaddle["already_exists"])
            {
                paddleToAddToArray["health"] = newPaddle["health"];
                float crackOpacity = (float)1.0 - ((int)newPaddle["health"] / (float)Game.MaxHealth);
                crackOpacity *= (float)0.7;
                if ((int)newPaddle["health"] == 1)
                {
                    crackOpacity = 1;
                }
                paddleNode.GetNode<Sprite>("Crack").Modulate = new Color(1, 1, 1, crackOpacity);
            }
            else
            {
                paddleToAddToArray["health"] = Game.MaxHealth;
            }
            EmitSignal("PaddleCreated", paddleToAddToArray);
            if (discordManager.IsLobbyOwner())
            {
                paddleToAddToArray["already_exists"] = true;
                GColl.Dictionary newData = paddleToAddToArray.Duplicate(true);
                if (game.UserId == long.Parse((string)newPaddle["id"]) && (bool)newPaddle["has_pad"])
                {
                    newData["pad"] = newPaddle["pad"];
                }
                else
                {
                    newData["has_pad"] = false;
                }
                GColl.Dictionary paddleData = new GColl.Dictionary();
                paddleData.Add("paddle_data", newData);
                discordManager.SendAll(paddleData, true);
            }
            Paddles.Add(paddleToAddToArray);
            AddChild(paddleNode);
        }
    }

    public void RemovePaddles(long id)
    {
        GColl.Array<GColl.Dictionary> paddlesToClear = new GColl.Array<GColl.Dictionary>();
        foreach (GColl.Dictionary paddle in Paddles)
        {
            if (id == long.Parse((string)paddle["id"]))
            {
                paddlesToClear.Add(paddle);
            }
        }
        foreach (GColl.Dictionary paddle in paddlesToClear)
        {
            Paddles.Remove(paddle);
        }
    }

    public void UpdatePaddles(GColl.Array newPaddles)
    {
        if (!game.IsPlaying) return;
        for (int i = 0; i < newPaddles.Count; i++)
        {
            GColl.Dictionary newPaddle = (GColl.Dictionary)newPaddles[i];
            string paddleName = (string)newPaddle["name"];
            Paddle paddleNode = GetNode<Paddle>(paddleName);
            if (discordManager.IsLobbyOwner())
            {
                (Paddles[i] as GColl.Dictionary)["position"] = paddleNode.Position;
                (Paddles[i] as GColl.Dictionary)["rotation"] = paddleNode.Rotation;
                if (game.UserId == long.Parse((string)newPaddle["id"]))
                {
                    SetPaddleInputs(paddleName, GetPaddleInputs(paddleName));
                }
            }
            else
            {
                (Paddles[i] as GColl.Dictionary)["position"] = newPaddle["position"];
                (Paddles[i] as GColl.Dictionary)["rotation"] = newPaddle["rotation"];
                paddleNode.Position = (Vector2)newPaddle["position"];
                paddleNode.Rotation = (float)newPaddle["rotation"];
                if (game.UserId == long.Parse((string)newPaddle["id"]))
                {
                    GColl.Dictionary inputData = new GColl.Dictionary();
                    inputData.Add("paddle", paddleName);
                    inputData.Add("inputs", GetPaddleInputs(paddleName));
                    discordManager.SendOwner(inputData, false);
                }
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

    public GColl.Dictionary GetPaddleInputs(string paddle)
    {
        GColl.Dictionary inputs = new GColl.Dictionary();
        inputs.Add("velocity", new Vector2());
        inputs.Add("rotation", (float)0.0);
        inputs.Add("dash", false);
        if (!game.IsPlaying) return inputs;
        int pad = InputList[paddle];
        if (pad == -1)
        {
            inputs["velocity"] = new Vector2(
                GetKey((int)KeyList.D) - GetKey((int)KeyList.A),
                GetKey((int)KeyList.S) - GetKey((int)KeyList.W)
            ).Normalized() * Game.MoveSpeed;
            inputs["dash"] = Input.IsKeyPressed((int)KeyList.Shift);
            inputs["rotation"] = Mathf.Deg2Rad(
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
                inputs["velocity"] = leftStick * Game.MoveSpeed;
            }
            inputs["dash"] = Input.IsJoyButtonPressed(pad, (int)JoystickList.L2);
            if (rightStick.Length() > 0.7)
            {
                Paddle paddleNode = GetNode<Paddle>(paddle);
                inputs["rotation"] = paddleNode.GetAngleTo(paddleNode.Position + rightStick) * 0.1;
            }
        }
        return inputs;
    }

    public void SetPaddleInputs(string paddle, GColl.Dictionary inputs)
    {
        GetNodeOrNull<Paddle>(paddle)?.SetInputs(inputs);
    }

    public void DamagePaddle(string paddleName)
    {
        int paddleIndex = 0;
        for (; paddleIndex < Paddles.Count; paddleIndex++)
        {
            GColl.Dictionary testPaddle = (GColl.Dictionary)Paddles[paddleIndex];
            if (paddleName == (string)testPaddle["name"])
            {
                break;
            }
        }
        GColl.Dictionary thing = (GColl.Dictionary)Paddles[paddleIndex];
        Paddle paddleNode = GetNode<Paddle>(paddleName);
        thing["health"] = (int)thing["health"] - 1;
        float crackOpacity = (float)1.0 - ((int)thing["health"] / (float)Game.MaxHealth);
        crackOpacity *= (float)0.7;
        if ((int)thing["health"] == 1)
        {
            crackOpacity = 1;
        }
        paddleNode.GetNode<Sprite>("Crack").Modulate = new Color(1, 1, 1, crackOpacity);
        if ((int)thing["health"] < 1)
        {
            EmitSignal("PaddleDestroyed", thing["name"] + " was destroyed");
            if (discordManager.IsLobbyOwner())
            {
                paddleNode.Position = ((Node2D)Spawns[paddleNode.GetIndex()]).Position;
                paddleNode.Rotation = ((Node2D)Spawns[paddleNode.GetIndex()]).Rotation;
            }
            paddleNode.GetNode<Sprite>("Crack").Modulate = new Color(1, 1, 1, 0);
            thing["health"] = Game.MaxHealth;
        }
        if (discordManager.IsLobbyOwner())
        {
            GColl.Dictionary paddleData = new GColl.Dictionary();
            paddleData.Add("paddle", paddleName);
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
