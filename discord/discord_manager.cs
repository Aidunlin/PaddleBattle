using Godot;
using Discord;

public class discord_manager : Node {
	public Discord.Discord discord;
	public ActivityManager activityManager;
	static long clientId = 862090452361674762;
	
	public override void _Ready() {
		discord = new Discord.Discord(clientId, (ulong)CreateFlags.NoRequireDiscord);
		activityManager = discord.GetActivityManager();
	}
	
	public void UpdateActivity(string details = "", string state = "") {
		Activity activity = new Activity {
			Details = details,
			State = state,
			Assets = {
				LargeImage = "paddlebattle"
			}
		};
		activityManager.UpdateActivity(activity, (result) => {
			if (result != Result.Ok) {
				GD.PrintErr("Error updating activity: ", result);
			}
		});
	}
	
	public override void _Process(float delta) {
		discord.RunCallbacks();
	}
}
