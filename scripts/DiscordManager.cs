using Godot;
using Discord;
using Godot.Collections;

public class DiscordManager : Node
{
    [Signal] public delegate void Error();
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

    public Discord.Discord discord;
    public ActivityManager activityManager;
    public LobbyManager lobbyManager;
    public UserManager userManager;
    public RelationshipManager relationshipManager;

    [Export] public long DiscordId = 862090452361674762;
    [Export] public long LobbyOwnerId = 0;
    [Export] public long CurrentLobbyId = 0;
    [Export] public bool IsRunning = false;

    public override void _PhysicsProcess(float delta)
    {
        if (IsRunning)
        {
            discord.RunCallbacks();
            lobbyManager.FlushNetwork();
        }
    }

    public void Start(string instance)
    {
        System.Environment.SetEnvironmentVariable("DISCORD_INSTANCE_ID", instance);
        discord = new Discord.Discord(DiscordId, (ulong)CreateFlags.Default);
        userManager = discord.GetUserManager();
        activityManager = discord.GetActivityManager();
        lobbyManager = discord.GetLobbyManager();
        relationshipManager = discord.GetRelationshipManager();

        discord.SetLogHook(LogLevel.Debug, (level, message) =>
        {
            GD.Print("Discord: ", level, " - ", message);
        });

        userManager.OnCurrentUserUpdate += () =>
        {
            EmitSignal("UserUpdated");
        };

        activityManager.OnActivityJoin += (secret) =>
        {
            JoinLobby(secret);
        };

        activityManager.OnActivityInvite += (ActivityActionType type, ref User user, ref Activity activity) =>
        {
            EmitSignal("InviteReceived", user.Id, user.Username);
        };

        lobbyManager.OnNetworkMessage += (lobbyId, userId, channelId, data) =>
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

        lobbyManager.OnMemberConnect += (lobbyId, userId) =>
        {
            UpdateActivity(true);
            userManager.GetUser(userId, (Result result, ref User user) =>
            {
                if (result == Result.Ok)
                {
                    EmitSignal("MemberConnected", userId, user.Username);
                }
            });
        };

        lobbyManager.OnMemberDisconnect += (lobbyId, userId) =>
        {
            if (userId == LobbyOwnerId)
            {
                LeaveLobby();
            }
            UpdateActivity(true);
            userManager.GetUser(userId, (Result result, ref User user) =>
            {
                if (result == Result.Ok)
                {
                    EmitSignal("MemberDisconnected", userId, user.Username);
                }
            });
        };

        relationshipManager.OnRefresh += () =>
        {
            UpdateRelationships();
        };

        relationshipManager.OnRelationshipUpdate += (ref Relationship rel) =>
        {
            UpdateRelationships();
        };

        UpdateActivity(false);
        IsRunning = true;
    }

    public void UpdateActivity(bool inLobby)
    {
        Activity activity = new Activity();
        if (inLobby)
        {
            activity.Secrets.Join = lobbyManager.GetLobbyActivitySecret(CurrentLobbyId);
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
        activityManager.UpdateActivity(activity, (result) =>
        {
            if (result != Result.Ok)
            {
                EmitSignal("Error", "Failed to update activity: " + result);
            }
        });
    }

    public void InitNetworking()
    {
        lobbyManager.ConnectNetwork(CurrentLobbyId);
        lobbyManager.OpenNetworkChannel(CurrentLobbyId, (byte)ChannelType.Unreliable, false);
        lobbyManager.OpenNetworkChannel(CurrentLobbyId, (byte)ChannelType.Reliable, true);
    }

    public string GetUserName()
    {
        return userManager.GetCurrentUser().Username;
    }

    public long GetUserId()
    {
        return userManager.GetCurrentUser().Id;
    }

    public long GetLobbyOwnerId()
    {
        if (CurrentLobbyId == 0)
        {
            return 0;
        }
        else
        {
            return lobbyManager.GetLobby(CurrentLobbyId).OwnerId;
        }
    }

    public bool IsLobbyOwner()
    {
        return GetLobbyOwnerId() == userManager.GetCurrentUser().Id;
    }

    public void Send(long userId, Dictionary data, bool reliable)
    {
        lobbyManager.SendNetworkMessage(
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
            foreach (User user in lobbyManager.GetMemberUsers(CurrentLobbyId))
            {
                Send(user.Id, data, reliable);
            }
        }
    }

    public void CreateLobby()
    {
        LobbyTransaction txn = lobbyManager.GetLobbyCreateTransaction();
        lobbyManager.CreateLobby(txn, (Result result, ref Lobby lobby) =>
        {
            if (result == Result.Ok)
            {
                CurrentLobbyId = lobby.Id;
                LobbyOwnerId = lobby.OwnerId;
                InitNetworking();
                UpdateActivity(true);
                EmitSignal("LobbyCreated");
            }
            else
            {
                EmitSignal("Error", "Failed to create lobby: " + result);
            }
        });
    }

    public void JoinLobby(string secret)
    {
        LeaveLobby();
        lobbyManager.ConnectLobbyWithActivitySecret(secret, (Result result, ref Lobby lobby) =>
        {
            if (result == Result.Ok)
            {
                CurrentLobbyId = lobby.Id;
                LobbyOwnerId = GetLobbyOwnerId();
                InitNetworking();
                UpdateActivity(true);
            }
            else
            {
                EmitSignal("Error", "Failed to join lobby: " + result);
            }
        });
    }

    public void LeaveLobby()
    {
        if (CurrentLobbyId != 0)
        {
            lobbyManager.DisconnectLobby(CurrentLobbyId, result =>
            {
                if (result == Result.Ok)
                {
                    CurrentLobbyId = 0;
                    LobbyOwnerId = 0;
                    UpdateActivity(false);
                }
                else
                {
                    EmitSignal("Error", "Failed to leave lobby: " + result);
                }
            });
        }
    }

    public void UpdateRelationships()
    {
        relationshipManager.Filter((ref Relationship rel) =>
        {
            return rel.Type == RelationshipType.Friend && rel.Presence.Status != Status.Offline;
        });
    }

    public Array GetFriends()
    {
        Array friends = new Array();
        for (int i = 0; i < relationshipManager.Count(); i++)
        {
            Relationship rel = relationshipManager.GetAt((uint)i);
            Dictionary friend = new Dictionary();
            friend.Add("UserName", rel.User.Username);
            friend.Add("Id", rel.User.Id.ToString());
            friends.Add(friend);
        }
        return friends;
    }

    public void SendInvite(long userId)
    {
        activityManager.SendInvite(userId, ActivityActionType.Join, "", result =>
        {
            if (result != Result.Ok)
            {
                EmitSignal("Error", "Failed to send invite");
            }
        });
    }

    public void AcceptInvite(long userId)
    {
        activityManager.AcceptInvite(userId, result =>
        {
            if (result != Result.Ok)
            {
                EmitSignal("Error", "Failed to accept invite");
            }
        });
    }
}
