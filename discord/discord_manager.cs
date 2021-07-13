using Godot;
using Discord;
using System;

public class discord_manager : Node {
	public Discord.Discord discord;
	public ActivityManager activityManager;
	public LobbyManager lobbyManager;
	public UserManager userManager;
	static long clientId = 862090452361674762;
	long currentLobby = 0;

	// Set to false when making a release
	bool devMode = true;
	
	public override void _Ready() {
		if (devMode) {
			var discordInstanceId = "0";
			var file = new File();
			if (file.FileExists("user://discord.json")) {
				file.Open("user://discord.json", File.ModeFlags.Read);
				var oldInstanceId = file.GetLine();
				if (oldInstanceId.Contains("0")) {
					discordInstanceId = "1";
				} else {
					discordInstanceId = "0";
				}
				file.Close();
			}
			file.Open("user://discord.json", File.ModeFlags.Write);
			file.StoreLine(discordInstanceId);
			file.Close();
			System.Environment.SetEnvironmentVariable("DISCORD_INSTANCE_ID", discordInstanceId);
		}

		discord = new Discord.Discord(clientId, (ulong)CreateFlags.NoRequireDiscord);
		activityManager = discord.GetActivityManager();
		lobbyManager = discord.GetLobbyManager();
		userManager = discord.GetUserManager();

		activityManager.OnActivityJoin += secret => {
			lobbyManager.ConnectLobbyWithActivitySecret(secret, (Result result, ref Lobby lobby) => {
				if (result == Result.Ok) {
					currentLobby = lobby.Id;
					GD.Print("Joined lobby: ", currentLobby);
					UpdateActivity("Battling it out", true);
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
				}
			});
		};

		lobbyManager.OnLobbyDelete += (lobbyId, reason) => {
			currentLobby = 0;
			GD.Print("Lobby was deleted: " + lobbyId + " with reason: " + reason);
			UpdateActivity("Thinking about battles", false);
		};

		UpdateActivity("Thinking about battles", false);
	}

	public void CreateLobby() {
		LobbyTransaction txn = lobbyManager.GetLobbyCreateTransaction();
		lobbyManager.CreateLobby(txn, (Result result, ref Lobby lobby) => {
			if (result == Result.Ok) {
				currentLobby = lobby.Id;
				GD.Print("Created lobby: ", currentLobby);
				UpdateActivity("Battling it out", true);
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
			activity.Party.Size = new PartySize {
				MaxSize = 8,
				CurrentSize = lobbyManager.MemberCount(currentLobby)
			};
		}

		activityManager.UpdateActivity(activity, (result) => {
			if (result != Result.Ok) {
				GD.PrintErr("Error updating activity: ", result);
			}
		});
	}
	
	public override void _Process(float delta) {
		discord.RunCallbacks();
		lobbyManager.FlushNetwork();
	}
}
