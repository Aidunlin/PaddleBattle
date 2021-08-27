using Godot;
using Discord;

public class discord_manager : Node {
	[Signal] public delegate void error();
	[Signal] public delegate void user_updated();
	[Signal] public delegate void lobby_created();
	[Signal] public delegate void member_connected();
	[Signal] public delegate void member_disconnected();
	[Signal] public delegate void message_received();
	[Signal] public delegate void invite_received();
	
	public enum channels {
		UPDATE_OBJECTS,
		SET_PADDLE_INPUTS,
		JOIN_GAME,
		UNLOAD_GAME,
		CREATE_PADDLE,
		DAMAGE_PADDLE,
	};
	
	public Discord.Discord discord;
	public ActivityManager activity_manager;
	public LobbyManager lobby_manager;
	public UserManager user_manager;
	public RelationshipManager relationship_manager;
	
	public long discord_id = 862090452361674762;
	public long lobby_owner_id = 0;
	public long current_lobby_id = 0;
	public bool started = false;
	
	public override void _PhysicsProcess(float delta) {
		if (started) {
			discord.RunCallbacks();
			lobby_manager.FlushNetwork();
		}
	}
	
	public void start(string instance) {
		System.Environment.SetEnvironmentVariable("DISCORD_INSTANCE_ID", instance);
		discord = new Discord.Discord(discord_id, (ulong)CreateFlags.Default);
		discord.SetLogHook(LogLevel.Debug, (LogLevel level, string message) => {
			GD.Print("Discord: ", level, " - ", message);
		});
		activity_manager = discord.GetActivityManager();
		lobby_manager = discord.GetLobbyManager();
		user_manager = discord.GetUserManager();
		relationship_manager = discord.GetRelationshipManager();
		user_manager.OnCurrentUserUpdate += () => {
			EmitSignal("user_updated");
		};
		activity_manager.OnActivityJoin += secret => {
			join_lobby(secret);
		};
		activity_manager.OnActivityInvite += (ActivityActionType type, ref User user, ref Activity activity) => {
			EmitSignal("invite_received", user.Id, user.Username);
		};
		lobby_manager.OnNetworkMessage += (lobby_id, user_id, channel_id, data) => {
			EmitSignal("message_received", channel_id, data);
		};
		lobby_manager.OnMemberConnect += (lobby_id, user_id) => {
			update_activity(true);
			user_manager.GetUser(user_id, (Result result, ref User user) => {
				if (result == Result.Ok) {
					EmitSignal("member_connected", user_id, user.Username);
				}
			});
		};
		lobby_manager.OnMemberDisconnect += (lobby_id, user_id) => {
			update_activity(true);
			lobby_owner_id = get_lobby_owner_id();
			user_manager.GetUser(user_id, (Result result, ref User user) => {
				if (result == Result.Ok) {
					EmitSignal("member_disconnected", user_id, user.Username);
				}
			});
		};
		relationship_manager.OnRefresh += () => {
			update_relationships();
		};
		relationship_manager.OnRelationshipUpdate += (ref Relationship rel) => {
			update_relationships();
		};
		update_activity(false);
		started = true;
	}
	
	public void update_activity(bool in_lobby) {
		var activity = new Activity();
		if (Godot.OS.IsDebugBuild()) {
			activity.Details = "Debugging";
		}
		if (in_lobby) {
			activity.State = "Battling it out";
			activity.Secrets.Join = lobby_manager.GetLobbyActivitySecret(current_lobby_id);
			activity.Party.Id = current_lobby_id.ToString();
			activity.Party.Size.CurrentSize = lobby_manager.MemberCount(current_lobby_id);
			activity.Party.Size.MaxSize = 8;
			activity.Party.Privacy = ActivityPartyPrivacy.Public;
		} else {
			activity.State = "Thinking about battles";
		}
		activity.Assets.LargeImage = "paddlebattle";
		activity_manager.UpdateActivity(activity, (result) => {
			if (result != Result.Ok) {
				EmitSignal("error", "Failed to update activity: " + result);
			}
		});
	}

	public void open_channel(channels channel, bool reliable) {
		lobby_manager.OpenNetworkChannel(current_lobby_id, (byte)channel, reliable);
	}
	
	public void init_networking() {
		lobby_manager.ConnectNetwork(current_lobby_id);
		open_channel(channels.UPDATE_OBJECTS, false);
		open_channel(channels.SET_PADDLE_INPUTS, false);
		open_channel(channels.JOIN_GAME, true);
		open_channel(channels.UNLOAD_GAME, true);
		open_channel(channels.CREATE_PADDLE, true);
		open_channel(channels.DAMAGE_PADDLE, true);
	}
	
	public string get_user_name() {
		return user_manager.GetCurrentUser().Username;
	}
	
	public long get_user_id() {
		return user_manager.GetCurrentUser().Id;
	}
	
	public long get_lobby_owner_id() {
		if (current_lobby_id != 0) {
			return lobby_manager.GetLobby(current_lobby_id).OwnerId;
		}
		return 0;
	}
	
	public bool is_lobby_owner() {
		return get_lobby_owner_id() == user_manager.GetCurrentUser().Id;
	}
	
	public void send(long user_id, byte channel, object data) {
		lobby_manager.SendNetworkMessage(current_lobby_id, user_id, channel, GD.Var2Bytes(data));
	}
	
	public void send_owner(byte channel, object data) {
		send(get_lobby_owner_id(), channel, data);
	}
	
	public void send_all(byte channel, object data) {
		if (current_lobby_id != 0) {
			foreach (var user in lobby_manager.GetMemberUsers(current_lobby_id)) {
				send(user.Id, channel, data);
			}
		}
	}
	
	public void create_lobby() {
		var txn = lobby_manager.GetLobbyCreateTransaction();
		txn.SetCapacity(8);
		txn.SetType(LobbyType.Public);
		lobby_manager.CreateLobby(txn, (Result result, ref Lobby lobby) => {
			if (result == Result.Ok) {
				current_lobby_id = lobby.Id;
				lobby_owner_id = lobby.OwnerId;
				init_networking();
				update_activity(true);
				EmitSignal("lobby_created");
			} else {
				EmitSignal("error", "Failed to create lobby: " + result);
			}
		});
	}
	
	public void join_lobby(string secret) {
		leave_lobby();
		lobby_manager.ConnectLobbyWithActivitySecret(secret, (Result result, ref Lobby lobby) => {
			if (result == Result.Ok) 	{
				current_lobby_id = lobby.Id;
				lobby_owner_id = get_lobby_owner_id();
				init_networking();
				update_activity(true);
			} else {
				EmitSignal("error", "Failed to join lobby: " + result);
			}
		});
	}
	
	public void leave_lobby() {
		if (current_lobby_id != 0) {
			lobby_manager.DisconnectLobby(current_lobby_id, result => {
				if (result == Result.Ok) {
					current_lobby_id = 0;
					lobby_owner_id = 0;
					update_activity(false);
				} else {
				EmitSignal("error", "Failed to leave lobby: " + result);
				}
			});
		}
	}
	
	public void update_relationships() {
		relationship_manager.Filter((ref Relationship rel) => {
			return rel.Type == RelationshipType.Friend && rel.Presence.Status != Status.Offline;
			// return rel.Presence.Activity.ApplicationId == discord_id;
		});
	}
	
	public Godot.Collections.Dictionary get_relationships() {
		var friends = new Godot.Collections.Dictionary();
		for (int i = 0; i < relationship_manager.Count(); i++) {
			var rel = relationship_manager.GetAt((uint)i);
			friends.Add(rel.User.Username, rel.User.Id);
		}
		return friends;
	}
	
	public void send_invite(long user_id) {
		activity_manager.SendInvite(user_id, ActivityActionType.Join, "Come battle it out!", result => {
			if (result != Result.Ok) {
				EmitSignal("error", "Failed to send invite");
			}
		});
	}
	
	public void accept_invite(long user_id) {
		activity_manager.AcceptInvite(user_id, result => {
			if (result != Result.Ok) {
				EmitSignal("error", "Failed to accept invite");
			}
		});
	}
}
