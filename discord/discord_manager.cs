using Godot;
using System;
using Discord;
using System.Collections.Generic;

public class discord_manager : Node {
	public Discord.Discord discord;
	public ActivityManager activityManager;
	public LobbyManager lobbyManager;
	public UserManager userManager;
	public RelationshipManager relationshipManager;
	long lobbyId = 0;
	long startTime;
	long clientId = 862090452361674762;
	
	public override void _Ready() {
		discord = new Discord.Discord(clientId, (ulong)CreateFlags.NoRequireDiscord);
		activityManager = discord.GetActivityManager();
		lobbyManager = discord.GetLobbyManager();
		userManager = discord.GetUserManager();
		relationshipManager = discord.GetRelationshipManager();
		
		activityManager.OnActivityJoin += secret => {
			lobbyManager.ConnectLobbyWithActivitySecret(secret, (Result result, ref Lobby lobby) => {
				if (result == Result.Ok) {
					GD.Print("Successfully joined a lobby: ", lobby.Id);
					lobbyId = lobby.Id;
					UpdateActivity("In lobby...", true, true);
					UpdateMemberList();
				} else {
					GD.PrintErr("Failed to join a lobby: ", result);
				}
			});
		};
		
		lobbyManager.OnMemberConnect += (lobbyId, userId) => {
			GD.Print("Member connected: ", userId);
			UpdateActivity("In lobby...", false, true);
			UpdateMemberList();
		};
		lobbyManager.OnMemberDisconnect += (lobbyId, userId) => {
			GD.Print("Member disconnected: ", userId);
			UpdateActivity("In lobby...", false, true);
			UpdateMemberList();
		};
		
		UpdateActivity("In menu...", true, false);
	}
	
	public void CreateLobby() {
		LobbyTransaction txn = lobbyManager.GetLobbyCreateTransaction();
		lobbyManager.CreateLobby(txn, (Result result, ref Lobby lobby) => {
			if (result == Result.Ok) {
				lobbyId = lobby.Id;
				GD.Print("Made a new lobby: ", lobbyId);
				UpdateActivity("In lobby...", true, true);
				UpdateMemberList();
			} else {
				GD.PrintErr("Failed to make a new lobby: ", result);
			}
		});
	}
	
	public void LeaveLobby() {
		lobbyManager.DisconnectLobby(lobbyId, (result) => {
			if (result == Discord.Result.Ok) {
				GD.Print("Successfully left the lobby.");
				UpdateActivity("In menu...", true, false);
			} else {
				GD.PrintErr("Failed to leave the lobby: ", result);
			}
		});
	}
	
	public void UpdateActivity(string state, bool resetTime, bool inLobby) {
		if (resetTime) {
			startTime = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
		}
		
		Activity activity = new Activity {
			State = state,
			Timestamps = {
				Start = startTime
			},
			Assets = {
				LargeImage = "paddlebattle",
				LargeText = "PaddleBattle"
			}
		};
		
		if (inLobby) {
			activity.Secrets.Join = lobbyManager.GetLobbyActivitySecret(lobbyId);
			activity.Party.Id = lobbyId.ToString();
			activity.Party.Size = new PartySize {
				MaxSize = 10,
				CurrentSize = lobbyManager.MemberCount(lobbyId)
			};
		}
		
		activityManager.UpdateActivity(activity, (result) => {
			if (result == Result.Ok) {
				GD.Print("Successfully updated activity.");
			} else {
				GD.PrintErr("Error starting activity: ", result);
			}
		});
	}
	
	public void UpdateMemberList() {
		GD.Print("Members:");
		GD.Print("===========");
		IEnumerable<User> lobbyMembers = lobbyManager.GetMemberUsers(lobbyId);
		foreach (User member in lobbyMembers) {
			GD.Print(member.Username);
		}
	}
	
	public override void _Process(float delta) {
		discord.RunCallbacks();
		lobbyManager.FlushNetwork();
	}
}
