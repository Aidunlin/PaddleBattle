# Paddle Battle
A multiplayer action game with pong-like mechanics (in early development).

Paddle Battle is a hobby project of mine. It's my first dive into game development, and I've been really enjoying it so far. I mostly just add/edit stuff that I want to add/edit. I do want the game to eventually have items/powerups, maps/gamemodes, and some type of singleplayer experience, among other things.

With that being said, I hope you find enjoyment in Paddle Battle. Any feedback, be it praise, suggestions, or criticisms, is greatly appreciated.

## How to play

Head over to the [releases page](https://github.com/Aidunlin/PaddleBattle/releases) and download the latest zip. Extract and run the exe (some releases have a .pck file, be sure to keep it in the same directory).

Press start, enter, or keypad enter on your input device to join the game. Up to 8 people can play at once!

Controls as of 0.4.0:
* Controller - Left stick to move, right stick to rotate, left trigger to dash
* Keyboard (left side) - WASD to move, G and H to rotate, shift to dash
* Keyboard (right side) - Arrow keys to move, keypad 2 and 3 to rotate, keypad 1 to dash (turn on Num Lock)

Note that controls, mechanics, and features will change and have changed across releases prior to 1.0. The full release will include customizable key binds, game options, and more.

Your objective is to bounce balls off of the enemy paddle's back side, causing them to lose health. How you do this is up to you.

## How to play over LAN

0.4.0 introduces online multiplayer. By enabling the Open to LAN option and pressing play, you will act as the host. Others will connect to you by simply typing in your IP address and pressing join. This works without any additional setup over your network (including VPNs like Hamachi or Tunngle), but if you want to play with people who aren't in the same network, you have to port forward with the port used by Paddle Battle (8910).

Regardless of whether you are on the host machine or a client machine, you can have multiple people playing on your device as long as there is room available. For example, 2 people on the same computer can play with 3 people on a different computer. Each additional player on the same device will have the same in-game name followed by a number to differentiate between them. If you want to leave (if you are on a client) or end the game (if you are on the host), you can do so by pressing Escape.