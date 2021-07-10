using Godot;
using System;
using Discord;

public class discord_manager : Node {
	public Discord.Discord discord;
	public ActivityManager activityManager;
	public override void _Ready() {
		discord = new Discord.Discord(862090452361674762, (ulong)CreateFlags.NoRequireDiscord);
		activityManager = discord.GetActivityManager();
		Activity activity = new Activity {
			Assets = {
				LargeImage = "paddlebattle",
				LargeText = "PaddleBattle"
			}
		};
		activityManager.UpdateActivity(activity, (result) => {
			if (result != Result.Ok) {
				GD.Print("Error starting activity: ", result);
			}
		});
	}
	public override void _Process(float delta) {
		discord.RunCallbacks();
	}
}
