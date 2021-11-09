using Godot;
using Godot.Collections;

public class Main : Node
{
    public Game game;
    public DiscordManager discordManager;

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
        
        camera = GetNode<Camera>("Camera");
        mapManager = GetNode<MapManager>("MapManager");
        paddleManager = GetNode<PaddleManager>("PaddleManager");
        ballManager = GetNode<BallManager>("BallManager");
        hudManager = GetNode<HUDManager>("HUDManager");
        menuManager = GetNode<MenuManager>("CanvasLayer/MenuManager");

        discordManager.Connect("UserUpdated", this, "GetUser");
        discordManager.Connect("LobbyCreated", this, "CreateGame", new Array(){null});
        discordManager.Connect("MemberConnected", this, "HandleConnect");
        discordManager.Connect("MemberDisconnected", this, "HandleDisconnect");
        discordManager.Connect("MessageReceived", this, "HandleNetworkMessage");

        paddleManager.Connect("OptionsRequested", menuManager, "ShowOptions");
        paddleManager.Connect("PaddleDestroyed", menuManager, "AddMessage");
        paddleManager.Connect("PaddleCreated", hudManager, "CreateHUD");
        paddleManager.Connect("PaddleRemoved", hudManager, "RemoveHUD");

        menuManager.Connect("MapSwitched", this, "SwitchMap");
        menuManager.Connect("EndRequested", this, "UnloadGame", new Array(){"You left the lobby"});

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
                objectData.Add("paddles", paddleManager.Paddles);
                objectData.Add("balls", ballManager.Balls);
                discordManager.SendAll(objectData, false);
                UpdateObjects(paddleManager.Paddles, ballManager.Balls);
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

    public void HandleNetworkMessage(byte[] message)
    {
        object dataObject = GD.Bytes2Var(message);
        Dictionary data = (Dictionary)dataObject;
        if (data.Contains("paddles") && data.Contains("balls"))
        {
            UpdateObjects((Array)data["paddles"], (Array)data["balls"]);
        }
        else if (data.Contains("paddle") && data.Contains("inputs"))
        {
            paddleManager.SetPaddleInputs((string)data["paddle"], (Dictionary)data["inputs"]);
        }
        else if (data.Contains("paddles") && data.Contains("map"))
        {
            JoinGame((Array)data["paddles"], (string)data["map"]);
        }
        else if (data.Contains("reason"))
        {
            UnloadGame((string)data["reason"]);
        }
        else if (data.Contains("paddle"))
        {
            paddleManager.DamagePaddle((string)data["paddle"]);
        }
        else if (data.Contains("paddle_data"))
        {
            paddleManager.CreatePaddle((Dictionary)data["paddle_data"]);
        }
    }

    public void HandleConnect(long id, string name)
    {
        menuManager.AddMessage(name + " joined the lobby");
        if (discordManager.IsLobbyOwner())
        {
            Dictionary welcomeData = new Dictionary();
            welcomeData.Add("paddles", paddleManager.Paddles);
            welcomeData.Add("map", game.Map);
            discordManager.Send(id, welcomeData, true);
        }
    }

    public void HandleDisconnect(long id, string name)
    {
        paddleManager.RemovePaddles(id);
        menuManager.AddMessage(name + " left the lobby");;
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
        discordManager.LeaveLobby();
        game.IsPlaying = false;
        camera.ResetNoSpawn();
        mapManager.Reset();
        paddleManager.Reset();
        ballManager.Reset();
        hudManager.Reset();
        menuManager.Reset(msg);
    }
}
