using Godot;
using Godot.Collections;

public class Main : Node
{
    public Game game;
    public DiscordManager discordManager;
    public InputManager inputManager;

    public Camera camera;
    public MapManager mapManager;
    public PaddleManager paddleManager;
    public BallManager ballManager;
    public HUDManager hudManager;
    public MenuManager menuManager;

    public override void _Ready()
    {
        game = GetNode<Game>("/root/Game");
        discordManager = GetNode<DiscordManager>("/root/DiscordManager");
        inputManager = GetNode<InputManager>("/root/InputManager");

        camera = GetNode<Camera>("Camera");
        mapManager = GetNode<MapManager>("MapManager");
        paddleManager = GetNode<PaddleManager>("PaddleManager");
        ballManager = GetNode<BallManager>("BallManager");
        hudManager = GetNode<HUDManager>("HUDManager");
        menuManager = GetNode<MenuManager>("CanvasLayer/MenuManager");

        discordManager.Connect("Error", this, "HandleDiscordError");
        discordManager.Connect("UserUpdated", this, "GetUser");
        discordManager.Connect("LobbyCreated", this, "CreateGame", new Array() { null });
        discordManager.Connect("MemberConnected", this, "HandleDiscordConnect");
        discordManager.Connect("MemberDisconnected", this, "HandleDiscordDisconnect");
        discordManager.Connect("MessageReceived", this, "HandleDiscordMessage");

        inputManager.Connect("CreatePaddleRequested", paddleManager, "CreatePaddleFromInput");
        inputManager.Connect("OptionsRequested", menuManager, "ShowOptions");
        paddleManager.Connect("PaddleDestroyed", menuManager, "AddMessage");
        paddleManager.Connect("PaddleCreated", hudManager, "CreateHUD");
        paddleManager.Connect("PaddleRemoved", hudManager, "RemoveHUD");

        menuManager.Connect("MapSwitched", this, "SwitchMap");
        menuManager.Connect("EndRequested", this, "UnloadGame", new Array() { "You left the lobby" });

        if (!OS.IsDebugBuild())
        {
            menuManager.StartDiscord("0");
        }
    }

    public override void _PhysicsProcess(float delta)
    {
        if (game.IsPlaying)
        {
            if (discordManager.IsLobbyOwner())
            {
                Dictionary objectData = new Dictionary();
                objectData.Add("Paddles", paddleManager.GetPaddles());
                objectData.Add("Balls", ballManager.GetBalls());
                discordManager.SendAll(objectData, false);
                UpdateObjects(paddleManager.GetPaddles(), ballManager.GetBalls());
            }
            camera.MoveAndZoom(paddleManager.GetChildren());
        }
    }

    public void SwitchMap()
    {
        menuManager.MapButton.Text = mapManager.Switch();
    }

    public void GetUser()
    {
        if (!game.IsPlaying && !menuManager.MainMenuNode.Visible)
        {
            game.UserId = discordManager.GetUserId();
            game.UserName = discordManager.GetUserName();
        }
        menuManager.ShowUserAndMenu();
    }

    public void HandleDiscordError(string message)
    {
        GD.PrintErr(message);
    }

    public void HandleDiscordMessage(byte[] message)
    {
        Dictionary data = (Dictionary)GD.Bytes2Var(message);
        if (data.Contains("Paddles") && data.Contains("Balls"))
        {
            UpdateObjects((Array)data["Paddles"], (Array)data["Balls"]);
        }
        else if (data.Contains("Paddle") && data.Contains("Inputs"))
        {
            paddleManager.SetPaddleInputs((string)data["Paddle"], (Dictionary)data["Inputs"]);
        }
        else if (data.Contains("Paddles") && data.Contains("Map"))
        {
            JoinGame((Array)data["Paddles"], (string)data["Map"]);
        }
        else if (data.Contains("Reason"))
        {
            UnloadGame((string)data["Reason"]);
        }
        else if (data.Contains("Paddle"))
        {
            paddleManager.DamagePaddle((string)data["Paddle"]);
        }
        else if (data.Contains("PaddleData"))
        {
            paddleManager.CreatePaddle((Dictionary)data["PaddleData"]);
        }
    }

    public void HandleDiscordConnect(long id, string name)
    {
        menuManager.AddMessage(name + " joined the lobby");
        if (discordManager.IsLobbyOwner())
        {
            Dictionary welcomeData = new Dictionary();
            welcomeData.Add("Paddles", paddleManager.GetPaddles());
            welcomeData.Add("Map", game.Map);
            discordManager.Send(id, welcomeData, true);
        }
    }

    public void HandleDiscordDisconnect(long id, string name)
    {
        paddleManager.RemovePaddles(id);
        menuManager.AddMessage(name + " left the lobby");
    }

    public void JoinGame(Array paddles, string mapName)
    {
        CreateGame(mapName);
        foreach (var paddle in paddles)
        {
            paddleManager.CreatePaddle((Dictionary)paddle);
        }
    }

    public void CreateGame(string mapName = null)
    {
        GD.Randomize();
        LoadGame(mapName ?? game.Map, Color.FromHsv(GD.Randf(), (float)0.5, 1));
    }

    public void LoadGame(string mapName, Color mapColor)
    {
        mapManager.LoadMap(mapName, mapColor);
        camera.Reset(mapManager.GetCameraSpawn());
        paddleManager.Spawns = mapManager.GetPaddleSpawns();
        ballManager.Spawns = mapManager.GetBallSpawns();
        ballManager.CreateBalls();
        menuManager.AddMessage("Press A/Enter to join");
        menuManager.MainMenuNode.Hide();
        game.IsPlaying = true;
    }

    public void UpdateObjects(Array paddles, Array balls)
    {
        if (game.IsPlaying)
        {
            paddleManager.UpdatePaddles(paddles);
            hudManager.MoveHUDs(paddles);
            ballManager.UpdateBalls(balls);
        }
    }

    public void UnloadGame(string msg)
    {
        game.Reset();
        discordManager.LeaveLobby();
        inputManager.Reset();
        camera.ResetNoSpawn();
        mapManager.Reset();
        paddleManager.Reset();
        ballManager.Reset();
        hudManager.Reset();
        menuManager.Reset(msg);
    }
}
