# PaddleBattle
A multiplayer action game with pong-like mechanics (in early development).

PaddleBattle is a hobby project of mine. It's my first dive into game development, and I've been really enjoying it so far. I mostly just add/edit stuff that I want to add/edit. I do want the game to eventually have items/powerups, maps/gamemodes, and some type of singleplayer experience.

With that being said, I hope you find enjoyment in PaddleBattle. Any feedback, be it praise, suggestions, or criticisms, is greatly appreciated.

## How to play

Simply download the project, unzip, and run `godot.exe`! Releases prior to 0.6.0 require a couple more steps to run the game.

0.6.0 implements the Discord Game SDK! Discord's networking layer replaces LAN multiplayer (introduced in 0.4.0). You can send and receive invites in-game, and your in-game username is copied straight from Discord. Additionally, if the lobby creator leaves, the game will (almost seamlessly) switch to a new owner.

When the game is running in debug mode (i.e. with a console output), the game will make you choose the Discord instance to connect to. If you haven't installed another version of Discord, just choose `Discord 0`.

Your objective is to bounce balls off of the enemy paddle's back side, causing them to lose health. How you do this is up to you. Good luck and have fun!

Controls:
* Controller (A to join) - `LS` to move, `RS` to rotate, `LT` to dash
* Keyboard (enter to join) - `WASD` to move, `comma` and `period` to rotate, `shift` to dash
