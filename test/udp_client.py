"""Tiny UDP client to verify the vision service stream.

Binds the keypoint UDP port and prints a one-line summary per packet so you can
confirm the service is detecting a player and publishing at a steady rate before
wiring up the Godot front-end.

Run (in a second terminal, while vision_service.py is running):
    python test/udp_client.py --port 5005
"""

import argparse
import json
import socket

DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 5005


def main():
    parser = argparse.ArgumentParser(description="Print keypoint packets from the vision service")
    parser.add_argument("--host", default=DEFAULT_HOST, help="UDP bind host")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help="UDP bind port")
    args = parser.parse_args()

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind((args.host, args.port))
    print(f"Listening on udp://{args.host}:{args.port}  (Ctrl+C to stop)")

    while True:
        data, _ = sock.recvfrom(65535)
        try:
            packet = json.loads(data.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            print("Received malformed packet")
            continue

        players = packet.get("players", [])
        if not players:
            status = "no players"
        else:
            noses = [f"({p.get('nose', {}).get('x')}, {p.get('nose', {}).get('y')})" for p in players]
            status = f"{len(players)} player(s)  noses={', '.join(noses)}"
        print(f"frame {packet.get('frame'):>6}  {packet.get('width')}x{packet.get('height')}  {status}")


if __name__ == "__main__":
    main()
