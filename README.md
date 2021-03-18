# PaddleBattle
A multiplayer action game with pong-like mechanics (in early development).

PaddleBattle is a hobby project of mine. It's my first dive into game development, and I've been really enjoying it so far. I mostly just add/edit stuff that I want to add/edit. I do want the game to eventually have items/powerups, maps/gamemodes, and some type of singleplayer experience, among other things.

With that being said, I hope you find enjoyment in PaddleBattle. Any feedback, be it praise, suggestions, or criticisms, is greatly appreciated.

## How to play

Head over to the [releases page](https://github.com/Aidunlin/PaddleBattle/releases) to download and extract the latest source code zip. As of 0.4.1, you'll need a [standard Godot 3.2.3 binary](https://downloads.tuxfamily.org/godotengine/3.2.3/) for your platform. After extracting, place the Godot executable in the same directory as the source code and run it. If you want to open the Godot editor, simply drag and drop the project.godot file onto the Godot binary.

Controls as of 0.4.1:
* Controller (A to join) - Left stick to move, right stick to rotate, left trigger to dash
* Keyboard (enter to join) - WASD to move, comma and period to rotate, shift to dash

Note that controls, mechanics, and features will change and have changed across releases prior to 1.0.0. The full release will include customizable key binds, game options, and more.

Your objective is to bounce balls off of the enemy paddle's back side, causing them to lose health. How you do this is up to you. Up to 8 can play at once!

## How to play over LAN

0.4.0 introduces online multiplayer. By enabling the Open to LAN option and pressing play, you will act as the host. Others will connect to you by simply typing in your IP address and pressing join. This works without any additional setup over your network (including VPNs like Hamachi or Tunngle), but if you want to play with people who aren't in the same network, you have to port forward with the port used by PaddleBattle, which is 8910.

Regardless of whether you are on the host machine or a client machine, you can have multiple people playing on your device as long as there is room available. For example, 2 people on the same computer can play with 3 people on a different computer. Each additional player on the same device will have the same in-game name followed by a number to differentiate between them. If you want to leave (if you are on a client) or end the game (if you are on the host), you can do so by pressing escape or both start and select.
