using Godot;
using Discord;
using Godot.Collections;

public class DiscordManager : Node
{
    [Signal] public delegate void UserUpdated();
    [Signal] public delegate void LobbyUpdated();
    [Signal] public delegate void MemberConnected();
    [Signal] public delegate void MemberDisconnected();
    [Signal] public delegate void MessageReceived();
    [Signal] public delegate void InviteReceived();
    [Signal] public delegate void RelationshipsRefreshed();

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
            if (level < LogLevel.Info)
            {
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
            LeaveLobby(secret);
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
                    UpdateActivity();
                }
                else
                {
                    GD.PrintErr("Discord: Failed to get user details");
                }
            });
        };

        _lobbyManager.OnMemberDisconnect += (lobbyId, userId) =>
        {
            _userManager.GetUser(userId, (Result result, ref User user) =>
            {
                if (result == Result.Ok)
                {
                    GD.Print("Discord: ", user.Username, " disconnected");
                    EmitSignal("MemberDisconnected", userId, user.Username);
                    UpdateActivity();
                }
            });
        };

        _relationshipManager.OnRefresh += () =>
        {
            UpdateRelationships();
            GD.Print("Discord: Relationships refreshed");
            EmitSignal("RelationshipsRefreshed");
        };

        _relationshipManager.OnRelationshipUpdate += (ref Relationship rel) =>
        {
            UpdateRelationships();
            GD.Print("Discord: Relationships refreshed");
        };

        IsRunning = true;
        GD.Print("Discord: Instance connected");
        CreateLobby();
    }

    public void UpdateActivity()
    {
        Activity activity = new Activity();

        if (CurrentLobbyId != 0)
        {
            activity.Secrets.Join = _lobbyManager.GetLobbyActivitySecret(CurrentLobbyId);
            activity.Party.Id = CurrentLobbyId.ToString();
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
        return GetLobbyOwnerId() == GetUserId();
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
        if (!IsLobbyOwner())
        {
            Send(GetLobbyOwnerId(), data, reliable);
        }
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

        _lobbyManager.CreateLobby(txn, (Result result, ref Lobby lobby) =>
        {
            if (result == Result.Ok)
            {
                CurrentLobbyId = lobby.Id;
                InitNetworking();
                UpdateActivity();
                EmitSignal("LobbyUpdated");
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
        _lobbyManager.ConnectLobbyWithActivitySecret(secret, (Result result, ref Lobby lobby) =>
        {
            if (result == Result.Ok)
            {
                CurrentLobbyId = lobby.Id;
                InitNetworking();
                UpdateActivity();
                EmitSignal("LobbyUpdated");
                GD.Print("Discord: Lobby joined");
            }
            else
            {
                GD.PrintErr("Discord: Failed to join lobby: ", result);
            }
        });
    }

    public void LeaveLobby(string secretToJoin = null)
    {
        _lobbyManager.DisconnectLobby(CurrentLobbyId, result =>
        {
            if (result == Result.Ok)
            {
                CurrentLobbyId = 0;
                UpdateActivity();
                GD.Print("Discord: Lobby left");

                if (secretToJoin == null)
                {
                    CreateLobby();
                }
                else
                {
                    JoinLobby(secretToJoin);
                }
            }
            else
            {
                GD.PrintErr("Discord: Failed to leave lobby: ", result);
            }
        });
    }

    public void UpdateRelationships()
    {
        _relationshipManager.Filter((ref Relationship rel) =>
        {
            return rel.Type == RelationshipType.Friend && rel.Presence.Status != Status.Offline;
        });
    }

    public int GetLobbySize()
    {
        return (int)_lobbyManager.GetLobby(CurrentLobbyId).Capacity;
    }

    public Array<Dictionary> GetFriends()
    {
        Array<Dictionary> friends = new Array<Dictionary>();

        for (uint i = 0; i < _relationshipManager.Count(); i++)
        {
            User user = _relationshipManager.GetAt(i).User;
            Dictionary friend = new Dictionary();
            friend.Add("Username", user.Username);
            friend.Add("Id", user.Id.ToString());
            friends.Add(friend);
        }

        return friends;
    }

    public Array<Dictionary> GetMembers()
    {
        Array<Dictionary> members = new Array<Dictionary>();

        if (CurrentLobbyId != 0)
        {
            foreach (User user in _lobbyManager.GetMemberUsers(CurrentLobbyId))
            {
                Dictionary member = new Dictionary();
                member.Add("Username", user.Username);
                member.Add("Id", user.Id.ToString());
                members.Add(member);
            }
        }

        return members;
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
