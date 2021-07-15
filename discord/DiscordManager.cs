using Godot;
using Discord;
using System;

public class DiscordManager : Node {
	[Signal]
	public delegate void UserUpdated();

	[Signal]
	public delegate void LobbyCreated();

	[Signal]
	public delegate void LobbyConnected();

	[Signal]
	public delegate void LobbyDeleted();

	[Signal]
	public delegate void MemberDisconnected(long userId);

	[Signal]
	public delegate void MessageReceived(byte channelId, byte[] data);

	public enum Channels {
		UpdateObjects,
		CheckClient,
		StartClientGame,
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

	public long currentLobby = 0;
	public User currentUser;
	public bool started = false;

	public void Start(string instance) {
		System.Environment.SetEnvironmentVariable("DISCORD_INSTANCE_ID", instance);
		discord = new Discord.Discord(862090452361674762, (ulong)CreateFlags.NoRequireDiscord);
		activityManager = discord.GetActivityManager();
		lobbyManager = discord.GetLobbyManager();
		userManager = discord.GetUserManager();

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
		if (currentLobby != 0) {
			return lobbyManager.GetLobby(currentLobby).OwnerId;
		} else {
			return 0;
		}
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
		var channels = Enum.GetValues(typeof(Channels));
		lobbyManager.OpenNetworkChannel(currentLobby, (byte)Channels.UpdateObjects, false);
		lobbyManager.OpenNetworkChannel(currentLobby, (byte)Channels.CheckClient, true);
		lobbyManager.OpenNetworkChannel(currentLobby, (byte)Channels.StartClientGame, true);
		lobbyManager.OpenNetworkChannel(currentLobby, (byte)Channels.UnloadGame, true);
		lobbyManager.OpenNetworkChannel(currentLobby, (byte)Channels.CreatePaddle, true);
		lobbyManager.OpenNetworkChannel(currentLobby, (byte)Channels.SetPaddleInputs, false);
		lobbyManager.OpenNetworkChannel(currentLobby, (byte)Channels.VibratePad, true);
		lobbyManager.OpenNetworkChannel(currentLobby, (byte)Channels.DamagePaddle, true);
	}

	public void SendData(long userId, byte channel, byte[] data) {
		lobbyManager.SendNetworkMessage(currentLobby, userId, channel, data);
	}

	public void SendDataOwner(byte channel, byte[] data) {
		lobbyManager.SendNetworkMessage(currentLobby, GetLobbyOwnerId(), channel, data);
	}

	public void SendDataAll(byte channel, byte[] data) {
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
		}

		activityManager.UpdateActivity(activity, (result) => {
			if (result != Result.Ok) {
				GD.PrintErr("Error updating activity: ", result);
			}
		});
	}
	
	public override void _Process(float delta) {
		if (started) {
			discord.RunCallbacks();
			lobbyManager.FlushNetwork();
		}
	}
}
