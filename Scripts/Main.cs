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

        _discordManager.Connect("UserUpdated", _menuManager, "ShowUserAndMenu");
        _discordManager.Connect("LobbyUpdated", this, "HandleDiscordLobbyUpdate");
        _discordManager.Connect("MemberConnected", this, "HandleDiscordConnect");
        _discordManager.Connect("MemberDisconnected", this, "HandleDiscordDisconnect");
        _discordManager.Connect("MessageReceived", this, "HandleDiscordMessage");
        _discordManager.Connect("InviteReceived", _menuManager.LeftSideMenu, "AddInvite");
        _discordManager.Connect("RelationshipsRefreshed", _menuManager.RightSideMenu, "UpdateFriends");

        _inputManager.Connect("CreatePaddleRequested", _paddleManager, "CreatePaddleFromInput");
        _inputManager.Connect("OptionsRequested", _menuManager, "ShowOptions");

        _paddleManager.Connect("PaddleDestroyed", _menuManager.LeftSideMenu, "AddMessage");
        _paddleManager.Connect("PaddleCreated", _hudManager, "CreateHUD");
        _paddleManager.Connect("PaddleRemoved", _hudManager, "RemoveHUD");

        _menuManager.Connect("MapSwitched", this, "SwitchMap");
        _menuManager.Connect("PlayRequested", this, "CreateGame", new Array() { null });
        _menuManager.Connect("EndRequested", this, "EndGame");
        _menuManager.Connect("LeaveRequested", this, "LeaveGame");

        if (!OS.IsDebugBuild())
        {
            _menuManager.DiscordMenu.StartDiscord("0");
        }
    }

    public override void _PhysicsProcess(float delta)
    {
        if (_game.IsPlaying)
        {
            if (_discordManager.IsLobbyOwner())
            {
                var updateData = new Dictionary();
                updateData.Add("NetworkMessage", "UpdateObjects");
                updateData.Add("Paddles", _paddleManager.GetPaddles());
                updateData.Add("Balls", _ballManager.GetBalls());
                _discordManager.SendAll(updateData, false);
                UpdateObjects(_paddleManager.GetPaddles(), _ballManager.GetBalls());
            }

            _camera.MoveAndZoom(_paddleManager.GetChildren());
        }
    }

    public void HandleDiscordLobbyUpdate()
    {
        _menuManager.RightSideMenu.UpdateMembers();
        _menuManager.UpdateGameButtons();
    }

    public void HandleDiscordConnect(long id, string name)
    {
        HandleDiscordLobbyUpdate();
        _menuManager.LeftSideMenu.AddMessage(name + " connected");

        if (_discordManager.IsLobbyOwner() && _game.IsPlaying)
        {
            var playData = new Dictionary();
            playData.Add("NetworkMessage", "JoinGame");
            playData.Add("Paddles", _paddleManager.GetPaddles());
            playData.Add("Map", _mapManager.MapName);
            _discordManager.Send(id, playData, true);
        }
    }

    public void HandleDiscordDisconnect(long id, string name)
    {
        HandleDiscordLobbyUpdate();
        _paddleManager.RemovePaddles(id);
        _menuManager.LeftSideMenu.AddMessage(name + " disconnected");
    }

    public void HandleDiscordMessage(byte[] message)
    {
        var data = (Dictionary)GD.Bytes2Var(message);
        
        if (!data.Contains("NetworkMessage"))
        {
            return;
        }

        var messageType = (string)data["NetworkMessage"];

        if (messageType == "JoinGame")
        {
            JoinGame((Array)data["Paddles"], (string)data["Map"]);
        }
        else if (messageType == "UpdateObjects")
        {
            UpdateObjects((Array)data["Paddles"], (Array)data["Balls"]);
        }
        else if (messageType == "CreatePaddle")
        {
            _paddleManager.CreatePaddle((Dictionary)data["PaddleData"]);
        }
        else if (messageType == "SetPaddleInputs")
        {
            _paddleManager.SetPaddleInputs((string)data["Paddle"], (Dictionary)data["Inputs"]);
        }
        else if (messageType == "DamagePaddle")
        {
            _paddleManager.DamagePaddle((string)data["Paddle"]);
        }
        else if (messageType == "UnloadGame")
        {
            UnloadGame("The game ended");
        }
        else
        {
            GD.PrintErr("Main: Unknown network message type: ", messageType);
        }
    }

    public void SwitchMap()
    {
        _menuManager.MatchMenu.MapButton.Text = _mapManager.Switch();
    }

    public void LoadGame(string mapName, Color mapColor)
    {
        _mapManager.LoadMap(mapName, mapColor);
        _camera.Reset(_mapManager.GetCameraSpawn());
        _paddleManager.Spawns = _mapManager.GetPaddleSpawns();
        _ballManager.Spawns = _mapManager.GetBallSpawns();
        _ballManager.CreateBalls();
        _menuManager.LeftSideMenu.AddMessage("Press A/Enter to join");
        _menuManager.MainMenu.Hide();
        _menuManager.MatchMenu.Hide();
        _menuManager.SettingsMenu.Hide();
        _menuManager.OptionsMenu.Hide();
        _menuManager.RightSideMenu.Hide();
        _game.IsPlaying = true;
    }

    public void CreateGame(string mapName)
    {
        GD.Randomize();
        LoadGame(mapName ?? _mapManager.MapName, Color.FromHsv(GD.Randf(), 1, 1));

        if (_discordManager.IsLobbyOwner())
        {
            var playData = new Dictionary();
            playData.Add("NetworkMessage", "JoinGame");
            playData.Add("Paddles", _paddleManager.GetPaddles());
            playData.Add("Map", _mapManager.MapName);
            _discordManager.SendAll(playData, true);
        }
    }

    public void JoinGame(Array paddles, string mapName)
    {
        CreateGame(mapName);

        foreach (var paddle in paddles)
        {
            _paddleManager.CreatePaddle((Dictionary)paddle);
        }
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

    public void EndGame()
    {
        if (_discordManager.IsLobbyOwner())
        {
            UnloadGame("You ended the game");
            var endData = new Dictionary();
            endData.Add("NetworkMessage", "UnloadGame");
            _discordManager.SendAll(endData, true);
        }
    }

    public void LeaveGame()
    {
        _discordManager.LeaveLobby();
        UnloadGame("You left the lobby");
    }

    public void UnloadGame(string msg)
    {
        _game.Reset();
        _inputManager.Reset();
        _camera.Reset(Vector2.Zero);
        _mapManager.Reset();
        _paddleManager.Reset();
        _ballManager.Reset();
        _hudManager.Reset();
        _menuManager.Reset(msg);
    }
}
