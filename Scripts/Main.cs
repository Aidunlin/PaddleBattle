using Godot;
using Godot.Collections;

public class Main : Node
{
    private Game _game;
    private DiscordManager _discordManager;
    private InputManager _inputManager;

    private Camera _camera;
    private MapManager _mapManager;
    private PaddleManager _paddleManager;
    private BallManager _ballManager;
    private HUDManager _hudManager;
    private MenuManager _menuManager;

    public override void _Ready()
    {
        _game = GetNode<Game>("/root/Game");
        _discordManager = GetNode<DiscordManager>("/root/DiscordManager");
        _inputManager = GetNode<InputManager>("/root/InputManager");

        _camera = GetNode<Camera>("Camera");
        _mapManager = GetNode<MapManager>("MapManager");
        _paddleManager = GetNode<PaddleManager>("PaddleManager");
        _ballManager = GetNode<BallManager>("BallManager");
        _hudManager = GetNode<HUDManager>("HUDManager");
        _menuManager = GetNode<MenuManager>("CanvasLayer/MenuManager");

        _discordManager.Connect("UserUpdated", this, "HandleDiscordUserUpdate");
        // _discordManager.Connect("LobbyCreated", this, "CreateGame", new Array() { null });
        _discordManager.Connect("LobbyUpdated", _menuManager, "UpdateMembers");
        _discordManager.Connect("MemberConnected", this, "HandleDiscordConnect");
        _discordManager.Connect("MemberDisconnected", this, "HandleDiscordDisconnect");
        _discordManager.Connect("MessageReceived", this, "HandleDiscordMessage");

        _inputManager.Connect("CreatePaddleRequested", _paddleManager, "CreatePaddleFromInput");
        _inputManager.Connect("OptionsRequested", _menuManager, "ShowOptions");

        _paddleManager.Connect("PaddleDestroyed", _menuManager, "AddMessage");
        _paddleManager.Connect("PaddleCreated", _hudManager, "CreateHUD");
        _paddleManager.Connect("PaddleRemoved", _hudManager, "RemoveHUD");

        _menuManager.Connect("MapSwitched", this, "SwitchMap");
        _menuManager.Connect("PlayRequested", this, "CreateGame", new Array() { null });
        _menuManager.Connect("EndRequested", this, "UnloadGame", new Array() { "You left the lobby" });

        if (!OS.IsDebugBuild())
        {
            _menuManager.StartDiscord("0");
        }
    }

    public override void _PhysicsProcess(float delta)
    {
        if (_game.IsPlaying)
        {
            if (_discordManager.IsLobbyOwner())
            {
                Dictionary updateData = new Dictionary();
                updateData.Add("Paddles", _paddleManager.GetPaddles());
                updateData.Add("Balls", _ballManager.GetBalls());
                _discordManager.SendAll(updateData, false);
                UpdateObjects(_paddleManager.GetPaddles(), _ballManager.GetBalls());
            }

            _camera.MoveAndZoom(_paddleManager.GetChildren());
        }
    }

    public void SwitchMap()
    {
        _menuManager.MapButton.Text = _mapManager.Switch();
    }

    public void HandleDiscordUserUpdate()
    {
        if (!_game.IsPlaying && !_menuManager.MainMenuNode.Visible)
        {
            _game.UserId = _discordManager.GetUserId();
            _game.Username = _discordManager.GetUsername();
        }

        _menuManager.ShowUserAndMenu();
    }

    public void HandleDiscordMessage(byte[] message)
    {
        Dictionary data = (Dictionary)GD.Bytes2Var(message);

        if (data.Contains("Paddles") && data.Contains("Map"))
        {
            JoinGame((Array)data["Paddles"], (string)data["Map"]);
        }
        else if (data.Contains("Paddles") && data.Contains("Balls"))
        {
            UpdateObjects((Array)data["Paddles"], (Array)data["Balls"]);
        }
        else if (data.Contains("PaddleData"))
        {
            _paddleManager.CreatePaddle((Dictionary)data["PaddleData"]);
        }
        else if (data.Contains("Paddle") && data.Contains("Inputs"))
        {
            _paddleManager.SetPaddleInputs((string)data["Paddle"], (Dictionary)data["Inputs"]);
        }
        else if (data.Contains("Paddle"))
        {
            _paddleManager.DamagePaddle((string)data["Paddle"]);
        }
    }

    public void HandleDiscordConnect(long id, string name)
    {
        _menuManager.AddMessage(name + " joined the lobby");

        if (_discordManager.IsLobbyOwner())
        {
            Dictionary welcomeData = new Dictionary();
            welcomeData.Add("Paddles", _paddleManager.GetPaddles());
            welcomeData.Add("Map", _game.MapName);
            _discordManager.Send(id, welcomeData, true);
        }

        _menuManager.UpdateMembers();
    }

    public void HandleDiscordDisconnect(long id, string name)
    {
        _paddleManager.RemovePaddles(id);
        _menuManager.AddMessage(name + " left the lobby");
        _menuManager.UpdateMembers();
    }

    public void JoinGame(Array paddles, string mapName)
    {
        CreateGame(mapName);

        foreach (Dictionary paddle in paddles)
        {
            _paddleManager.CreatePaddle(paddle);
        }
    }

    public void CreateGame(string mapName = null)
    {
        GD.Randomize();
        LoadGame(mapName ?? _game.MapName, Color.FromHsv(GD.Randf(), 1, 1));
    }

    public void LoadGame(string mapName, Color mapColor)
    {
        _mapManager.LoadMap(mapName, mapColor);
        _camera.Reset(_mapManager.GetCameraSpawn());
        _paddleManager.Spawns = _mapManager.GetPaddleSpawns();
        _ballManager.Spawns = _mapManager.GetBallSpawns();
        _ballManager.CreateBalls();
        _menuManager.AddMessage("Press A/Enter to join");
        _menuManager.MainMenuNode.Hide();
        _menuManager.SidebarMargin.Hide();
        _game.IsPlaying = true;
    }

    public void UpdateObjects(Array paddles, Array balls)
    {
        if (_game.IsPlaying)
        {
            _paddleManager.UpdatePaddles(paddles);
            _hudManager.MoveHUDs(paddles);
            _ballManager.UpdateBalls(balls);
        }
    }

    public void UnloadGame(string msg)
    {
        _game.Reset();
        // _discordManager.LeaveLobby();
        _inputManager.Reset();
        _camera.Reset(Vector2.Zero);
        _mapManager.Reset();
        _paddleManager.Reset();
        _ballManager.Reset();
        _hudManager.Reset();
        _menuManager.Reset(msg);
    }
}
