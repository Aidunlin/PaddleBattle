using Godot;
using Discord;
using System;

public class DiscordManager : Node {
	[Signal] public delegate void UserUpdated();
	[Signal] public delegate void LobbyCreated();
	[Signal] public delegate void LobbyConnected();
	[Signal] public delegate void LobbyDeleted();
	[Signal] public delegate void MemberDisconnected(long userId);
	[Signal] public delegate void MessageReceived(byte channelId, byte[] data);
	[Signal] public delegate void RelationshipsUpdated();

	public enum Channels {
		UpdateObjects,
		CheckMember,
		JoinGame,
		UnloadGame,
		CreatePaddle,
		SetPaddleInputs,
		VibratePad,
		DamagePaddle,
	};

	public Discord.Discord discord;
	public ActivityManager activityManager;
	public LobbyManager lobbyManager;
	public UserManager userManager;
	public RelationshipManager relationshipManager;

	public long currentLobby = 0;
	public User currentUser;
	public bool started = false;
	public long clientId = 862090452361674762;

	public void Start(string instance) {
		System.Environment.SetEnvironmentVariable("DISCORD_INSTANCE_ID", instance);
		discord = new Discord.Discord(clientId, (ulong)CreateFlags.Default);
		activityManager = discord.GetActivityManager();
		lobbyManager = discord.GetLobbyManager();
		userManager = discord.GetUserManager();
		relationshipManager = discord.GetRelationshipManager();
		userManager.OnCurrentUserUpdate += () => {
			currentUser = userManager.GetCurrentUser();
			EmitSignal("UserUpdated");
		};
		activityManager.OnActivityJoin += secret => {
			lobbyManager.ConnectLobbyWithActivitySecret(secret, (Result result, ref Lobby lobby) => {
				if (result == Result.Ok) {
					currentLobby = lobby.Id;
					InitNetworking();
					GD.Print("Joined lobby: ", currentLobby);
					UpdateActivity("Battling it out", true);
					EmitSignal("LobbyConnected");
				} else {
					GD.PrintErr("Failed to join lobby: ", result);
				}
			});
		};
		lobbyManager.OnMemberConnect += (lobbyId, userId) => {
			UpdateActivity("Battling it out", true);
			GD.Print(lobbyManager.GetMemberUser(lobbyId, userId).Username + " joined the lobby");
		};
		lobbyManager.OnMemberDisconnect += (lobbyId, userId) => {
			UpdateActivity("Battling it out", true);
			userManager.GetUser(userId, (Result result, ref User user) => {
				if (result == Result.Ok) {
					GD.Print(user.Username + " left the lobby");
					EmitSignal("MemberDisconnected", userId);
				}
			});
		};
		lobbyManager.OnLobbyDelete += (lobbyId, reason) => {
			currentLobby = 0;
			GD.Print("Lobby was deleted: " + lobbyId + " with reason: " + reason);
			UpdateActivity("Thinking about battles", false);
			EmitSignal("LobbyDeleted");
		};
		lobbyManager.OnNetworkMessage += (lobbyId, userId, channelId, data) => {
			EmitSignal("MessageReceived", channelId, data);
		};
		relationshipManager.OnRefresh += () => {
			UpdateRelationships();
		};
		relationshipManager.OnRelationshipUpdate += (ref Relationship relationship) => {
			UpdateRelationships();
		};
		UpdateActivity("Thinking about battles", false);
		started = true;
	}

	public string GetUsername() {
		return currentUser.Username;
	}

	public long GetUserId() {
		return currentUser.Id;
	}

	public long GetLobbyOwnerId() {
		return currentLobby != 0 ? lobbyManager.GetLobby(currentLobby).OwnerId : 0;
	}

	public bool IsLobbyOwner() {
		return GetLobbyOwnerId() == currentUser.Id;
	}

	public void CreateLobby() {
		LobbyTransaction txn = lobbyManager.GetLobbyCreateTransaction();
		lobbyManager.CreateLobby(txn, (Result result, ref Lobby lobby) => {
			if (result == Result.Ok) {
				currentLobby = lobby.Id;
				InitNetworking();
				GD.Print("Created lobby: ", currentLobby);
				UpdateActivity("Battling it out", true);
				EmitSignal("LobbyCreated");
			} else {
				GD.PrintErr("Failed to create lobby: ", result);
			}
		});
	}

	public void LeaveLobby() {
		if (currentLobby != 0) {
			lobbyManager.DisconnectLobby(currentLobby, result => {
				if (result == Result.Ok) {
					currentLobby = 0;
					GD.Print("Left lobby");
					UpdateActivity("Thinking about battles", false);
				} else {
					GD.PrintErr("Failed to leave lobby: ", result);
				}
			});
		}
	}

	public void DeleteLobby() {
		if (currentLobby != 0) {
			lobbyManager.DeleteLobby(currentLobby, result => {
				if (result == Result.Ok) {
					currentLobby = 0;
					GD.Print("Deleted current lobby");
					UpdateActivity("Thinking about battles", false);
				} else {
					GD.PrintErr("Failed to delete lobby: ", result);
				}
			});
		}
	}

	public void InitNetworking() {
		lobbyManager.ConnectNetwork(currentLobby);
		lobbyManager.OpenNetworkChannel(currentLobby, (byte)Channels.UpdateObjects, false);
		lobbyManager.OpenNetworkChannel(currentLobby, (byte)Channels.CheckMember, true);
		lobbyManager.OpenNetworkChannel(currentLobby, (byte)Channels.JoinGame, true);
		lobbyManager.OpenNetworkChannel(currentLobby, (byte)Channels.UnloadGame, true);
		lobbyManager.OpenNetworkChannel(currentLobby, (byte)Channels.CreatePaddle, true);
		lobbyManager.OpenNetworkChannel(currentLobby, (byte)Channels.SetPaddleInputs, false);
		lobbyManager.OpenNetworkChannel(currentLobby, (byte)Channels.VibratePad, true);
		lobbyManager.OpenNetworkChannel(currentLobby, (byte)Channels.DamagePaddle, true);
	}

	public void SendData(long userId, byte channel, object data) {
		lobbyManager.SendNetworkMessage(currentLobby, userId, channel, GD.Var2Bytes(data));
	}

	public void SendDataOwner(byte channel, object data) {
		SendData(GetLobbyOwnerId(), channel, data);
	}

	public void SendDataAll(byte channel, object data) {
		if (currentLobby != 0) {
			foreach (var user in lobbyManager.GetMemberUsers(currentLobby)) {
				SendData(user.Id, channel, data);
			}
		}
	}
	
	public void UpdateActivity(string state, bool inLobby) {
		Activity activity = new Activity {
			State = state,
			Assets = {
				LargeImage = "paddlebattle"
			}
		};
		if (inLobby) {
			activity.Secrets.Join = lobbyManager.GetLobbyActivitySecret(currentLobby);
			activity.Party.Id = currentLobby.ToString();
			activity.Party.Size.CurrentSize =  lobbyManager.MemberCount(currentLobby);
			activity.Party.Size.MaxSize = 8;
			activity.Party.Privacy = ActivityPartyPrivacy.Public;
		}
		activityManager.UpdateActivity(activity, (result) => {
			if (result != Result.Ok) {
				GD.PrintErr("Error updating activity: ", result);
			}
		});
	}

	public void UpdateRelationships() {
		relationshipManager.Filter((ref Relationship relationship) => {
			return relationship.Presence.Activity.ApplicationId == clientId;
		});
		EmitSignal("RelationshipsUpdated");
	}

	public Godot.Collections.Array GetRelationships() {
		var friends = new Godot.Collections.Array();
		for (int i = 0; i < relationshipManager.Count(); i++) {
			var r = relationshipManager.GetAt((uint)i);
			var friend = new Godot.Collections.Dictionary();
			friend.Add("username", r.User.Username);
			friend.Add("id", r.User.Id);
			friends.Add(friend);
		}
		return friends;
	}

	public override void _Process(float delta) {
		if (started) {
			discord.RunCallbacks();
			lobbyManager.FlushNetwork();
		}
	}
}
