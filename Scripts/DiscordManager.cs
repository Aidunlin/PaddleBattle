using Godot;
using Discord;
using Godot.Collections;

public class DiscordManager : Node
{
    [Signal] public delegate void UserUpdated();
    [Signal] public delegate void LobbyCreated();
    [Signal] public delegate void MemberConnected();
    [Signal] public delegate void MemberDisconnected();
    [Signal] public delegate void MessageReceived();
    [Signal] public delegate void InviteReceived();

    public enum ChannelType
    {
        Unreliable,
        Reliable,
    }

    private Discord.Discord _discord;
    private ActivityManager _activityManager;
    private LobbyManager _lobbyManager;
    private UserManager _userManager;
    private RelationshipManager _relationshipManager;

    [Export] public long DiscordId = 862090452361674762;
    [Export] public long LobbyOwnerId = 0;
    [Export] public long CurrentLobbyId = 0;
    [Export] public bool IsRunning = false;

    public override void _PhysicsProcess(float delta)
    {
        if (IsRunning)
        {
            _discord.RunCallbacks();
            _lobbyManager.FlushNetwork();
        }
    }

    public void Start(string instance)
    {
        System.Environment.SetEnvironmentVariable("DISCORD_INSTANCE_ID", instance);
        _discord = new Discord.Discord(DiscordId, (ulong)CreateFlags.Default);
        _userManager = _discord.GetUserManager();
        _activityManager = _discord.GetActivityManager();
        _lobbyManager = _discord.GetLobbyManager();
        _relationshipManager = _discord.GetRelationshipManager();

        _discord.SetLogHook(LogLevel.Debug, (level, message) =>
        {
            if (level < LogLevel.Info) {
                GD.PrintErr("Discord: ", level, " - ", message);
            }
            else
            {
                GD.Print("Discord: ", level, " - ", message);
            }
        });

        _userManager.OnCurrentUserUpdate += () =>
        {
            GD.Print("Discord: User updated");
            EmitSignal("UserUpdated");
        };

        _activityManager.OnActivityJoin += (secret) =>
        {
            GD.Print("Discord: User joined activity");
            JoinLobby(secret);
        };

        _activityManager.OnActivityJoinRequest += (ref User user) => {
            GD.Print("Discord: ", user.Username, " requested to join");
        };

        _activityManager.OnActivityInvite += (ActivityActionType type, ref User user, ref Activity activity) =>
        {
            GD.Print("Discord: Invite received");
            EmitSignal("InviteReceived", user.Id, user.Username);
        };

        _lobbyManager.OnNetworkMessage += (lobbyId, userId, channelId, data) =>
        {
            try
            {
                EmitSignal("MessageReceived", data);
            }
            catch (System.Exception exc)
            {
                GD.Print(exc.ToString());
            }
        };

        _lobbyManager.OnMemberConnect += (lobbyId, userId) =>
        {
            _userManager.GetUser(userId, (Result result, ref User user) =>
            {
                if (result == Result.Ok)
                {
                    GD.Print("Discord: ", user.Username, " connected");
                    EmitSignal("MemberConnected", userId, user.Username);
                    UpdateActivity(true);
                }
                else
                {
                    GD.PrintErr("Discord: Failed to get user details");
                }
            });
        };

        _lobbyManager.OnMemberDisconnect += (lobbyId, userId) =>
        {
            if (userId == LobbyOwnerId)
            {
                LeaveLobby();
            }

            _userManager.GetUser(userId, (Result result, ref User user) =>
            {
                if (result == Result.Ok)
                {
                    GD.Print("Discord: ", user.Username, " disconnected");
                    EmitSignal("MemberDisconnected", userId, user.Username);
                    UpdateActivity(true);
                }
            });
        };

        _relationshipManager.OnRefresh += () =>
        {
            GD.Print("Discord: Relationships refreshed");
            UpdateRelationships();
        };

        _relationshipManager.OnRelationshipUpdate += (ref Relationship rel) =>
        {
            GD.Print("Discord: Relationships updated");
            UpdateRelationships();
        };

        UpdateActivity(false);
        IsRunning = true;
        GD.Print("Discord: Instance connected");
    }

    public void UpdateActivity(bool inLobby)
    {
        Activity activity = new Activity();

        if (inLobby)
        {
            activity.Secrets.Join = _lobbyManager.GetLobbyActivitySecret(CurrentLobbyId);
            activity.Party.Id = CurrentLobbyId.ToString();
            activity.State = "Battling it out";
        }
        else
        {
            activity.State = "Thinking about battles";
        }

        if (OS.IsDebugBuild())
        {
            activity.Details = "Debugging";
        }

        activity.Assets.LargeImage = "paddlebattle";

        _activityManager.UpdateActivity(activity, (result) =>
        {
            if (result == Result.Ok)
            {
                GD.Print("Discord: Activity updated");
            }
            if (result != Result.Ok)
            {
                GD.PrintErr("Discord: Failed to update activity: ", result);
            }
        });
    }

    public void InitNetworking()
    {
        _lobbyManager.ConnectNetwork(CurrentLobbyId);
        _lobbyManager.OpenNetworkChannel(CurrentLobbyId, (byte)ChannelType.Unreliable, false);
        _lobbyManager.OpenNetworkChannel(CurrentLobbyId, (byte)ChannelType.Reliable, true);
    }

    public string GetUsername()
    {
        return _userManager.GetCurrentUser().Username;
    }

    public long GetUserId()
    {
        return _userManager.GetCurrentUser().Id;
    }

    public long GetLobbyOwnerId()
    {
        if (CurrentLobbyId == 0)
        {
            return 0;
        }
        else
        {
            return _lobbyManager.GetLobby(CurrentLobbyId).OwnerId;
        }
    }

    public bool IsLobbyOwner()
    {
        return GetLobbyOwnerId() == _userManager.GetCurrentUser().Id;
    }

    public void Send(long userId, Dictionary data, bool reliable)
    {
        _lobbyManager.SendNetworkMessage(
            CurrentLobbyId,
            userId,
            (byte)(reliable ? ChannelType.Reliable : ChannelType.Unreliable),
            GD.Var2Bytes(data)
        );
    }

    public void SendOwner(Dictionary data, bool reliable)
    {
        Send(GetLobbyOwnerId(), data, reliable);
    }

    public void SendAll(Dictionary data, bool reliable)
    {
        if (CurrentLobbyId != 0)
        {
            foreach (User user in _lobbyManager.GetMemberUsers(CurrentLobbyId))
            {
                Send(user.Id, data, reliable);
            }
        }
    }

    public void CreateLobby()
    {
        LobbyTransaction txn = _lobbyManager.GetLobbyCreateTransaction();
        txn.SetType(LobbyType.Public);

        _lobbyManager.CreateLobby(txn, (Result result, ref Lobby lobby) =>
        {
            if (result == Result.Ok)
            {
                CurrentLobbyId = lobby.Id;
                LobbyOwnerId = lobby.OwnerId;
                InitNetworking();
                UpdateActivity(true);
                EmitSignal("LobbyCreated");
                GD.Print("Discord: Lobby created");
            }
            else
            {
                GD.PrintErr("Discord: Failed to create lobby: ", result);
            }
        });
    }

    public void JoinLobby(string secret)
    {
        LeaveLobby();

        _lobbyManager.ConnectLobbyWithActivitySecret(secret, (Result result, ref Lobby lobby) =>
        {
            if (result == Result.Ok)
            {
                CurrentLobbyId = lobby.Id;
                LobbyOwnerId = GetLobbyOwnerId();
                InitNetworking();
                UpdateActivity(true);
                GD.Print("Discord: Lobby joined");
            }
            else
            {
                GD.PrintErr("Discord: Failed to join lobby: ", result);
            }
        });
    }

    public void LeaveLobby()
    {
        if (CurrentLobbyId != 0)
        {
            _lobbyManager.DisconnectLobby(CurrentLobbyId, result =>
            {
                if (result == Result.Ok)
                {
                    CurrentLobbyId = 0;
                    LobbyOwnerId = 0;
                    UpdateActivity(false);
                    GD.Print("Discord: Lobby left");
                }
                else
                {
                    GD.PrintErr("Discord: Failed to leave lobby: ", result);
                }
            });
        }
    }

    public void UpdateRelationships()
    {
        _relationshipManager.Filter((ref Relationship rel) =>
        {
            return rel.Type == RelationshipType.Friend && rel.Presence.Status != Status.Offline;
        });
    }

    public Array GetFriends()
    {
        Array friends = new Array();

        for (int i = 0; i < _relationshipManager.Count(); i++)
        {
            Relationship rel = _relationshipManager.GetAt((uint)i);
            Dictionary friend = new Dictionary();
            friend.Add("Username", rel.User.Username);
            friend.Add("Id", rel.User.Id.ToString());
            friends.Add(friend);
        }
        
        return friends;
    }

    public void SendInvite(long userId)
    {
        _activityManager.SendInvite(userId, ActivityActionType.Join, "", result =>
        {
            if (result == Result.Ok)
            {
                GD.Print("Discord: Invite sent");
            }
            else
            {
                GD.PrintErr("Discord: Failed to send invite: ", result);
            }
        });
    }

    public void AcceptInvite(long userId)
    {
        _activityManager.AcceptInvite(userId, result =>
        {
            if (result == Result.Ok)
            {
                GD.Print("Discord: Invite accepted");
            }
            else
            {
                GD.PrintErr("Discord: Failed to accept invite: ", result);
            }
        });
    }
}
