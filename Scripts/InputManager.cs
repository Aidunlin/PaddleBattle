using Godot;
using Godot.Collections;

public class InputManager : Node
{
    private Game _game;
    private DiscordManager _discordManager;

    [Signal] public delegate void CreatePaddleRequested();
    [Signal] public delegate void OptionsRequested();

    [Export] public Dictionary<string, int> InputList = new Dictionary<string, int>();
    [Export] public Array UsedInputs = new Array();

    public override void _Ready()
    {
        _game = GetNode<Game>("/root/Game");
        _discordManager = GetNode<DiscordManager>("/root/DiscordManager");
    }

    public override void _PhysicsProcess(float delta)
    {
        if (_game.IsPlaying)
        {
            if (Input.IsKeyPressed((int)KeyList.Enter) && !InputListHasPad(-1))
            {
                EmitSignal("CreatePaddleRequested", -1);
            }

            foreach (int pad in Input.GetConnectedJoypads())
            {
                if (Input.IsJoyButtonPressed(pad, (int)JoystickList.Button0) && !InputListHasPad(pad))
                {
                    EmitSignal("CreatePaddleRequested", pad);
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

    public int GetKey(KeyList key)
    {
        return Input.IsKeyPressed((int)key) ? 1 : 0;
    }

    public float GetAxis(int pad, JoystickList axis)
    {
        return Input.GetJoyAxis(pad, (int)axis);
    }

    public Dictionary GetPaddleInputs(Paddle paddleNode)
    {
        Dictionary inputs = new Dictionary();
        inputs.Add("Velocity", new Vector2());
        inputs.Add("Rotation", (float)0.0);
        inputs.Add("Dash", false);

        if (!InputList.ContainsKey(paddleNode.Name) || !_game.IsPlaying)
        {
            return inputs;
        }

        int pad = InputList[paddleNode.Name];

        if (pad == -1)
        {
            inputs["Velocity"] = new Vector2(
                GetKey(KeyList.D) - GetKey(KeyList.A),
                GetKey(KeyList.S) - GetKey(KeyList.W)
            ).Normalized() * Game.MoveSpeed;

            inputs["Dash"] = Input.IsKeyPressed((int)KeyList.Shift);

            inputs["Rotation"] = Mathf.Deg2Rad(
                (GetKey(KeyList.Period) - GetKey(KeyList.Comma)) * 4
            );
        }
        else
        {
            Vector2 leftStick = new Vector2(
                GetAxis(pad, JoystickList.AnalogLx),
                GetAxis(pad, JoystickList.AnalogLy)
            );

            Vector2 rightStick = new Vector2(
                GetAxis(pad, JoystickList.AnalogRx),
                GetAxis(pad, JoystickList.AnalogRy)
            );

            if (leftStick.Length() > 0.2)
            {
                inputs["Velocity"] = leftStick * Game.MoveSpeed;
            }

            inputs["Dash"] = Input.IsJoyButtonPressed(pad, (int)JoystickList.L2);

            if (rightStick.Length() > 0.7)
            {
                inputs["Rotation"] = paddleNode.GetAngleTo(paddleNode.Position + rightStick) * 0.1;
            }
        }

        return inputs;
    }

    public void Reset()
    {
        InputList.Clear();
        UsedInputs.Clear();
    }
}
