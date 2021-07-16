using Godot;
using Discord;

public class DiscordManager : Node {
	[Signal] public delegate void user_updated();
	[Signal] public delegate void lobby_created();
	[Signal] public delegate void lobby_connected();
	[Signal] public delegate void lobby_deleted();
	[Signal] public delegate void member_disconnected(long user_id);
	[Signal] public delegate void message_received(byte channel_id, byte[] data);
	[Signal] public delegate void relationships_updated();
	[Signal] public delegate void invite_received(long user_id, string user_name);

	public enum Channels {
		UPDATE_OBJECTS,
		CHECK_MEMBER,
		JOIN_GAME,
		UNLOAD_GAME,
		CREATE_PADDLE,
		SET_PADDLE_INPUTS,
		VIBRATE_PAD,
		DAMAGE_PADDLE,
	};

	public Discord.Discord discord;
	public ActivityManager activity_manager;
	public LobbyManager lobby_manager;
	public UserManager user_manager;
	public RelationshipManager relationship_manager;

	public long client_id = 862090452361674762;
	public long lobby_owner_id = 0;
	public long current_lobby = 0;
	public User current_user;
	public bool started = false;

	public override void _Process(float delta) {
		if (started) {
			discord.RunCallbacks();
			lobby_manager.FlushNetwork();
		}
	}

	public void start(string instance) {
		System.Environment.SetEnvironmentVariable("DISCORD_INSTANCE_ID", instance);
		discord = new Discord.Discord(client_id, (ulong)CreateFlags.Default);
		activity_manager = discord.GetActivityManager();
		lobby_manager = discord.GetLobbyManager();
		user_manager = discord.GetUserManager();
		relationship_manager = discord.GetRelationshipManager();
		user_manager.OnCurrentUserUpdate += () => {
			current_user = user_manager.GetCurrentUser();
			EmitSignal("user_updated");
		};
		activity_manager.OnActivityJoin += secret => {
			lobby_manager.ConnectLobbyWithActivitySecret(secret, (Result result, ref Lobby lobby) => {
				if (result == Result.Ok) {
					current_lobby = lobby.Id;
					get_lobby_owner_id();
					init_networking();
					GD.Print("Joined lobby: ", current_lobby);
					update_activity("Battling it out", true);
					EmitSignal("lobby_connected");
				} else {
					GD.PrintErr("Failed to join lobby: ", result);
				}
			});
		};
		activity_manager.OnActivityInvite += (ActivityActionType type, ref User user, ref Activity activity) => {
			EmitSignal("invite_received", user.Id, user.Username);
		};
		lobby_manager.OnNetworkMessage += (lobby_id, user_i, channel_id, data) => {
			EmitSignal("message_received", channel_id, data);
		};
		lobby_manager.OnMemberConnect += (lobby_id, user_id) => {
			update_activity("Battling it out", true);
			GD.Print(lobby_manager.GetMemberUser(lobby_id, user_id).Username + " joined the lobby");
		};
		lobby_manager.OnMemberDisconnect += (lobby_id, user_id) => {
			update_activity("Battling it out", true);
			user_manager.GetUser(user_id, (Result result, ref User user) => {
				if (result == Result.Ok) {
					GD.Print(user.Username + " left the lobby");
					EmitSignal("member_disconnected", user_id);
					if (user_id == lobby_owner_id) {
						leave_lobby();
					}
				}
			});
		};
		lobby_manager.OnLobbyDelete += (lobby_id, reason) => {
			current_lobby = 0;
			lobby_owner_id = 0;
			GD.Print("Lobby was deleted: " + lobby_id + " with reason: " + reason);
			update_activity("Thinking about battles", false);
			EmitSignal("lobby_deleted");
		};
		relationship_manager.OnRefresh += () => {
			update_relationships();
		};
		relationship_manager.OnRelationshipUpdate += (ref Relationship relationship) => {
			update_relationships();
		};
		update_activity("Thinking about battles", false);
		started = true;
	}
	
	public void update_activity(string state, bool in_lobby) {
		var activity = new Activity {
			State = state,
			Assets = {
				LargeImage = "paddlebattle"
			}
		};
		if (in_lobby) {
			activity.Secrets.Join = lobby_manager.GetLobbyActivitySecret(current_lobby);
			activity.Party.Id = current_lobby.ToString();
			activity.Party.Size.CurrentSize =  lobby_manager.MemberCount(current_lobby);
			activity.Party.Size.MaxSize = 8;
			activity.Party.Privacy = ActivityPartyPrivacy.Public;
		}
		activity_manager.UpdateActivity(activity, (result) => {
			if (result != Result.Ok) {
				GD.PrintErr("Failed to update activity: ", result);
			}
		});
	}

	public void init_networking() {
		lobby_manager.ConnectNetwork(current_lobby);
		lobby_manager.OpenNetworkChannel(current_lobby, (byte)Channels.UPDATE_OBJECTS, false);
		lobby_manager.OpenNetworkChannel(current_lobby, (byte)Channels.CHECK_MEMBER, true);
		lobby_manager.OpenNetworkChannel(current_lobby, (byte)Channels.JOIN_GAME, true);
		lobby_manager.OpenNetworkChannel(current_lobby, (byte)Channels.UNLOAD_GAME, true);
		lobby_manager.OpenNetworkChannel(current_lobby, (byte)Channels.CREATE_PADDLE, true);
		lobby_manager.OpenNetworkChannel(current_lobby, (byte)Channels.SET_PADDLE_INPUTS, false);
		lobby_manager.OpenNetworkChannel(current_lobby, (byte)Channels.VIBRATE_PAD, true);
		lobby_manager.OpenNetworkChannel(current_lobby, (byte)Channels.DAMAGE_PADDLE, true);
	}

	public string get_user_name() {
		return current_user.Username;
	}

	public long get_user_id() {
		return current_user.Id;
	}

	public long get_lobby_owner_id() {
		lobby_owner_id = current_lobby != 0 ? lobby_manager.GetLobby(current_lobby).OwnerId : 0;
		return lobby_owner_id;
	}

	public bool is_lobby_owner() {
		return get_lobby_owner_id() == current_user.Id;
	}

	public void send_data(long user_id, byte channel, object data) {
		lobby_manager.SendNetworkMessage(current_lobby, user_id, channel, GD.Var2Bytes(data));
	}

	public void send_data_owner(byte channel, object data) {
		send_data(get_lobby_owner_id(), channel, data);
	}

	public void send_data_all(byte channel, object data) {
		if (current_lobby != 0) {
			foreach (var user in lobby_manager.GetMemberUsers(current_lobby)) {
				send_data(user.Id, channel, data);
			}
		}
	}

	public void create_lobby() {
		var txn = lobby_manager.GetLobbyCreateTransaction();
		lobby_manager.CreateLobby(txn, (Result result, ref Lobby lobby) => {
			if (result == Result.Ok) {
				current_lobby = lobby.Id;
				get_lobby_owner_id();
				init_networking();
				GD.Print("Created lobby: ", current_lobby);
				update_activity("Battling it out", true);
				EmitSignal("lobby_created");
			} else {
				GD.PrintErr("Failed to create lobby: ", result);
			}
		});
	}

	public void leave_lobby() {
		if (current_lobby != 0) {
			lobby_manager.DisconnectLobby(current_lobby, result => {
				if (result == Result.Ok) {
					current_lobby = 0;
					lobby_owner_id = 0;
					GD.Print("Left lobby");
					update_activity("Thinking about battles", false);
				} else {
					GD.PrintErr("Failed to leave lobby: ", result);
				}
			});
		}
	}

	public void delete_lobby() {
		if (current_lobby != 0) {
			lobby_manager.DeleteLobby(current_lobby, result => {
				if (result == Result.Ok) {
					current_lobby = 0;
					lobby_owner_id = 0;
					GD.Print("Deleted current lobby");
					update_activity("Thinking about battles", false);
				} else {
					GD.PrintErr("Failed to delete lobby: ", result);
				}
			});
		}
	}

	public void update_relationships() {
		relationship_manager.Filter((ref Relationship relationship) => {
			return relationship.Type == RelationshipType.Friend;
		});
		EmitSignal("relationships_updated");
	}

	public Godot.Collections.Array get_relationships() {
		var friends = new Godot.Collections.Array();
		for (int i = 0; i < relationship_manager.Count(); i++) {
			var relationship = relationship_manager.GetAt((uint)i);
			var friend = new Godot.Collections.Dictionary();
			friend.Add("name", relationship.User.Username);
			friend.Add("id", relationship.User.Id);
			friends.Add(friend);
		}
		return friends;
	}

	public void send_invite(long user_id) {
		activity_manager.SendInvite(user_id, ActivityActionType.Join, "Come battle it out!", result => {
			if (result != Result.Ok) {
				GD.PrintErr("Failed to send invite");
			}
		});
	}

	public void accept_invite(long user_id) {
		activity_manager.AcceptInvite(user_id, result => {
			if (result != Result.Ok) {
				GD.PrintErr("failed to accept invite");
			}
		});
	}
}
