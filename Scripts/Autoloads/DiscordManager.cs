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

    private Discord.Discord _discord;
    private ActivityManager _activityManager;
    private LobbyManager _lobbyManager;
    private UserManager _userManager;
    private RelationshipManager _relationshipManager;

    public const long AppId = 862090452361674762;

    [Export] public long CurrentLobbyId { get; set; } = 0;
    [Export] public bool IsRunning { get; set; } = false;

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
        _discord = new Discord.Discord(AppId, (ulong)CreateFlags.Default);
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
                    GD.PrintErr("Discord: Failed to get details of connected user");
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
                else
                {
                    GD.PrintErr("Discord: Failed to get details of disconnected user");
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
        var activity = new Activity();

        if (CurrentLobbyId != 0)
        {
            activity.Secrets.Join = _lobbyManager.GetLobbyActivitySecret(CurrentLobbyId);
            activity.Party.Id = CurrentLobbyId.ToString();
            activity.Party.Size.CurrentSize = _lobbyManager.MemberCount(CurrentLobbyId);
            activity.Party.Size.MaxSize = (int)_lobbyManager.GetLobby(CurrentLobbyId).Capacity;
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
        _lobbyManager.OpenNetworkChannel(CurrentLobbyId, 0, false);
        _lobbyManager.OpenNetworkChannel(CurrentLobbyId, 1, true);
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

    public void Send(long userId, Dictionary data, bool isReliable)
    {
        if (CurrentLobbyId != 0 && userId != GetUserId())
        {
            _lobbyManager.SendNetworkMessage(CurrentLobbyId, userId, (byte)(isReliable ? 1 : 0), GD.Var2Bytes(data));
        }
    }

    public void SendOwner(Dictionary data, bool isReliable)
    {
        if (!IsLobbyOwner())
        {
            Send(GetLobbyOwnerId(), data, isReliable);
        }
    }

    public void SendAll(Dictionary data, bool isReliable)
    {
        foreach (var user in _lobbyManager.GetMemberUsers(CurrentLobbyId))
        {
            Send(user.Id, data, isReliable);
        }
    }

    public void CreateLobby()
    {
        var transaction = _lobbyManager.GetLobbyCreateTransaction();
        transaction.SetCapacity(8);

        _lobbyManager.CreateLobby(transaction, (Result result, ref Lobby lobby) =>
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
        _relationshipManager.Filter((ref Relationship relationship) =>
        {
            return relationship.Type == RelationshipType.Friend && relationship.Presence.Status != Status.Offline;
        });
    }

    public int GetLobbyCapacity()
    {
        return (int)_lobbyManager.GetLobby(CurrentLobbyId).Capacity;
    }

    public Array<Dictionary> GetFriends()
    {
        var friends = new Array<Dictionary>();

        for (var i = 0; i < _relationshipManager.Count(); i++)
        {
            var relationship = _relationshipManager.GetAt((uint)i);
            var user = relationship.User;
            var friend = new Dictionary();
            friend.Add("Username", user.Username);
            friend.Add("UserId", user.Id.ToString());
            friend.Add("IsPlaying", relationship.Presence.Activity.ApplicationId == AppId);
            friends.Add(friend);
        }

        return friends;
    }

    public Array<Dictionary> GetMembers()
    {
        var members = new Array<Dictionary>();

        if (CurrentLobbyId != 0)
        {
            foreach (var user in _lobbyManager.GetMemberUsers(CurrentLobbyId))
            {
                var member = new Dictionary();
                member.Add("Username", user.Username);
                member.Add("UserId", user.Id.ToString());
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
