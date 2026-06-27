# ai_dance_game
Dance game implemented using yolo8 to detect player moves with a simple camera.

The main purpose is to remove the complex, expensive and out of production Kinect device.

Current on version 0.1. It's just a proof of concept :D

I'm happy with it because at least my girlfriend liked it. Hope someone else does too!

# Godot version (in progress)

The game is being migrated from pygame to a **Godot 4.x** front-end. Because Godot's
`CameraServer` has no Linux/Windows desktop backend, webcam capture and YOLOv8 pose
detection stay in Python and stream keypoints to Godot over UDP:

```
ai_camera_server/vision_service.py  ──(UDP keypoints, :5005)──▶  Godot client (scenes/ + scripts/)
  webcam + YOLOv8                                                  menus, audio, scoring, rendering
```

## Project layout

- `ai_camera_server/` — headless Python vision service (webcam + YOLOv8 → UDP keypoints)
- `game/` — shared Python pose code (keypoint extraction, geometry)
- `choreography/` — `dance.json` plus the tools to build it (`extract_poses.py`, `create_choreography.py`)
- `scenes/`, `scripts/` — the Godot 4.x client
- `test/` — `udp_client.py` to inspect the keypoint stream
- `media/`, `weights/` — the song and the YOLOv8 pose model

## Running it

Run the Python commands from the repository root (with your virtualenv active) so the
`game` package and the asset paths resolve.

1. Install Python deps: `pip install -r requirements.txt`
2. Start the vision service (keep it running): `python -m ai_camera_server.vision_service`
   - Debug preview window: `python -m ai_camera_server.vision_service --show`
   - Sanity-check the stream without Godot: `python test/udp_client.py`
3. Open the project (this folder) in the Godot 4.x editor and press Play, or run
   `godot --path .` from the command line. Pick **1 Player** or **2 Players** (stand
   side by side for two), get counted in, and dance! The round ends when the song
   stops (capped at 30s for testing) and a winner is shown.

## Choreography

The dance is stored entirely as keypoints in `choreography/dance.json`. The game draws
the reference pose for each move as a skeleton from that data, so no reference photos are
kept in the repo. To build a new choreography from your own pictures:

1. Put your reference photos in a local `pose_sources/` folder (gitignored).
2. Run `python -m choreography.extract_poses --images pose_sources --interval 3.0`.

# Demo video

https://github.com/user-attachments/assets/5d78917a-7d23-44e0-8a94-5fc282784caf

# Test Song credits:
Song: Cartoon, Jéja - On & On (feat. Daniel Levi) [NCS Release]
Music provided by NoCopyrightSounds
Free Download/Stream: http://ncs.io/onandon
Watch: http://youtu.be/K4DyBUG242c

Big thanks for the really great song!

# Future improvements:

* Make score points more fair
* Improve comparison between player pose and choreography move. It only measure distance in the current state.
* Add multi player mode
* Improve game play interface. It's too simple and not very exciting
* Improve game menus
* Add start screen
* Improve camera resolution handling
* Test with full body detection. Maybe buy a better camera
* Pack it so other people can use it.
