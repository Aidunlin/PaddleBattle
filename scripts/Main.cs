using Godot;
using System;
using Godot.Collections;
using Array = Godot.Collections.Array;

public class Main : Node
{
    public Camera2D camera;
    public Node mapManager;
    public Node paddleManager;
    public Node ballManager;
    public Control hudManager;
    public Control uiManager;
    public DiscordManager discordManager;
    public Game game;

    public override void _Ready()
    {
        camera = GetNode<Camera2D>("Camera");
        mapManager = GetNode<Node>("MapManager");
        paddleManager = GetNode<Node>("PaddleManager");
        ballManager = GetNode<Node>("BallManager");
        hudManager = GetNode<Control>("HUDManager");
        uiManager = GetNode<Control>("CanvasLayer/UIManager");
        discordManager = GetNode<DiscordManager>("/root/DiscordManager");
        game = GetNode<Game>("/root/Game");

        discordManager.Connect("UserUpdated", this, "GetUser");
        discordManager.Connect("LobbyCreated", this, "CreateGame", new Array(){null});
        discordManager.Connect("MemberConnected", this, "HandleConnect");
        discordManager.Connect("MemberDisconnected", this, "HandleDisconnect");
        discordManager.Connect("MessageReceived", this, "HandleMessage");

        paddleManager.Connect("options_requested", uiManager, "show_options");
        paddleManager.Connect("paddle_destroyed", uiManager, "add_message");
        paddleManager.Connect("paddle_created", hudManager, "CreateHUD");
        paddleManager.Connect("paddle_removed", hudManager, "RemoveHUD");

        uiManager.Connect("map_switched", this, "SwitchMap");
        uiManager.Connect("end_requested", this, "UnloadGame", new Array(){"You left the lobby"});

        if (!OS.IsDebugBuild())
        {
            uiManager.Call("start_discord");
        }
    }

    public override void _PhysicsProcess(float delta)
    {
        if (game.IsPlaying)
        {
            if (discordManager.IsLobbyOwner())
            {
                Dictionary objectData = new Dictionary();
                objectData.Add("paddles", paddleManager.Get("paddles"));
                objectData.Add("balls", ballManager.Get("Balls"));
                discordManager.SendAll(objectData, false);
                var paddles = paddleManager.Get("paddles");
                var balls = ballManager.Get("Balls");
                UpdateObjects(
                    paddleManager.Get("paddles"),
                    ballManager.Get("Balls")
                );
            }
            camera.Call("MoveAndZoom", paddleManager.GetChildren());
        }
    }

    public void SwitchMap()
    {
        Button mapButton = (Button)uiManager.Get("map_button");
        mapButton.Text = (string)mapManager.Call("Switch");
    }

    public void GetUser()
    {
        VBoxContainer mainMenuMode = (VBoxContainer)uiManager.Get("main_menu_node");
        if (!game.IsPlaying && !mainMenuMode.Visible)
        {
            game.UserId = discordManager.GetUserId();
            game.UserName = discordManager.GetUserName();
        }
        uiManager.Call("show_user_and_menu");
    }

    public void HandleMessage(byte[] message)
    {
        Dictionary data = (Dictionary)GD.Bytes2Var(message);
        if (data.Contains("paddles") && data.Contains("balls"))
        {
            UpdateObjects((Dictionary)data["paddles"], (Array<Dictionary>)data["balls"]);
        }
        else if (data.Contains("paddle") && data.Contains("inputs"))
        {
            paddleManager.Call("set_paddle_inputs", data["paddle"], data["inputs"]);
        }
        else if (data.Contains("paddles") && data.Contains("map"))
        {
            JoinGame((Dictionary)data["paddles"], (string)data["map"]);
        }
        else if (data.Contains("reason"))
        {
            UnloadGame((string)data["reason"]);
        }
        else if (data.Contains("paddle"))
        {
            paddleManager.Call("damage_paddle", data["paddle"]);
        }
        else if (data.Contains("name"))
        {
            paddleManager.Call("create_paddle", data);
        }
    }

    public void HandleConnect(long id, string name)
    {
        uiManager.Call("add_message", name + " joined the lobby");
        if (discordManager.IsLobbyOwner())
        {
            Dictionary welcomeData = new Dictionary();
            welcomeData.Add("paddles", paddleManager.Get("paddles"));
            welcomeData.Add("map", game.Map);
            discordManager.Send(id, welcomeData, true);
        }
    }

    public void HandleDisconnect(long id, string name)
    {
        paddleManager.Call("remove_paddles", id);
        uiManager.Call("add_message", name + " left the lobby");
    }

    public void JoinGame(Dictionary paddles, string mapName)
    {
        CreateGame(mapName);
        foreach (Dictionary paddle in paddles)
        {
            paddleManager.Call("create_paddle", paddle);
        }
    }

    public void CreateGame(string mapName = null)
    {
        GD.Randomize();
        LoadGame(mapName ?? game.Map, Color.FromHsv(GD.Randf(), (float)0.5, 1));
    }

    public void LoadGame(string mapName, Color mapColor)
    {
        mapManager.Call("LoadMap", mapName, mapColor);
        camera.Call("Reset", mapManager.Call("GetCameraSpawn"));
        paddleManager.Set("spawns", mapManager.Call("GetPaddleSpawns"));
        ballManager.Set("Spawns", mapManager.Call("GetBallSpawns"));
        ballManager.Call("CreateBalls");
        uiManager.Call("add_message", "Press A/Enter to join");
        ((VBoxContainer)uiManager.Get("main_menu_node")).Hide();
        game.IsPlaying = true;
    }

    public void UpdateObjects(object paddles, object balls)
    {
        if (game.IsPlaying)
        {
            paddleManager.Call("update_paddles", paddles);
            hudManager.Call("MoveHUDs", paddles);
            ballManager.Call("UpdateBalls", balls);
        }
    }

    public void UnloadGame(string msg)
    {
        discordManager.LeaveLobby();
        game.IsPlaying = false;
        camera.Call("ResetNoSpawn");
        mapManager.Call("Reset");
        paddleManager.Call("reset");
        ballManager.Call("Reset");
        hudManager.Call("Reset");
        uiManager.Call("reset", msg);
    }
}
