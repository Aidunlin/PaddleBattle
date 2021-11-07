using Godot;
using System;
using Discord;
using Godot.Collections;
using Array = Godot.Collections.Array;

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

    public long DiscordId = 862090452361674762;
    public long LobbyOwnerId = 0;
    public long CurrentLobbyId = 0;
    public bool IsRunning = false;

    public override void _PhysicsProcess(float delta)
    {
        if (!IsRunning) return;
        discord.RunCallbacks();
        lobbyManager.FlushNetwork();
    }

    public void Start(string instance)
    {
        System.Environment.SetEnvironmentVariable("DISCORD_INSTANCE_ID", instance);
        discord = new Discord.Discord(DiscordId, (ulong)CreateFlags.Default);
        discord.SetLogHook(LogLevel.Debug, (LogLevel level, string message) =>
        {
            GD.Print("Discord: ", level, " - ", message);
        });

        userManager = discord.GetUserManager();
        userManager.OnCurrentUserUpdate += () =>
        {
            EmitSignal("UserUpdated");
        };

        activityManager = discord.GetActivityManager();
        activityManager.OnActivityJoin += (secret) =>
        {
            JoinLobby(secret);
        };
        activityManager.OnActivityInvite += (ActivityActionType type, ref User user, ref Activity activity) =>
        {
            EmitSignal("InviteReceived", user.Id, user.Username);
        };

        lobbyManager = discord.GetLobbyManager();
        lobbyManager.OnNetworkMessage += (lobbyId, userId, channelId, data) =>
        {
            EmitSignal("MessageReceived", data);
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
            UpdateActivity(true);
            LobbyOwnerId = GetLobbyOwnerId();
            userManager.GetUser(userId, (Result result, ref User user) =>
            {
                if (result == Result.Ok)
                {
                    EmitSignal("MemberDisconnected", userId, user.Username);
                }
            });
        };

        relationshipManager = discord.GetRelationshipManager();
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
            activity.Party.Size.CurrentSize = lobbyManager.MemberCount(CurrentLobbyId);
            activity.Party.Size.MaxSize = 8;
            activity.State = "Battling it out";
        }
        else
        {
            activity.State = "Thinking about battles";
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

    public void Send(long userId, object data, bool reliable)
    {
        if (reliable)
        {
            lobbyManager.SendNetworkMessage(CurrentLobbyId, userId, (byte)ChannelType.Reliable, GD.Var2Bytes(data));
        }
        else
        {
            lobbyManager.SendNetworkMessage(CurrentLobbyId, userId, (byte)ChannelType.Unreliable, GD.Var2Bytes(data));
        }
    }

    public void SendOwner(object data, bool reliable)
    {
        Send(GetLobbyOwnerId(), data, reliable);
    }

    public void SendAll(object data, bool reliable)
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
        txn.SetCapacity(8);
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

    public Dictionary GetFriends()
    {
        Dictionary friends = new Dictionary();
        for (int i = 0; i < relationshipManager.Count(); i++)
        {
            Relationship rel = relationshipManager.GetAt((uint)i);
            friends.Add(rel.User.Username, rel.User.Id);
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
