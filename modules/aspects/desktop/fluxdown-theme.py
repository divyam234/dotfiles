"""Import and select the generated theme through FluxDown's local agent API."""

import json
import os
from pathlib import Path
import sys
import time
from urllib.parse import urlparse

import websocket


def apply_theme(theme_path, mode):
    theme = Path(theme_path).read_text()
    json.loads(theme)
    data_home = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
    agent_dir = data_home / "fluxdown/agent"
    deadline = time.monotonic() + 20
    while True:
        try:
            endpoint = json.loads((agent_dir / "gateway-endpoint.json").read_text())["rpcUrl"]
            address = urlparse(endpoint)
            if address.scheme != "ws" or address.hostname not in ("127.0.0.1", "::1"):
                raise ValueError("FluxDown agent endpoint must be a local WebSocket")
            token = (agent_dir / "agent.token").read_text().strip()
            socket = websocket.create_connection(
                endpoint,
                header={"Authorization": f"Bearer {token}"},
                suppress_origin=True,
                http_no_proxy=["127.0.0.1", "::1"],
                timeout=2,
            )
            break
        except (FileNotFoundError, ConnectionRefusedError, TimeoutError):
            if time.monotonic() >= deadline:
                raise TimeoutError("FluxDown agent did not start within 20 seconds") from None
            time.sleep(0.2)

    def call(request_id, method, params):
        socket.send(json.dumps({"jsonrpc": "2.0", "id": request_id, "method": method, "params": params}))
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError("FluxDown theme import timed out")
            socket.settimeout(remaining)
            response = json.loads(socket.recv())
            if response.get("id") != request_id:
                continue
            if "error" in response:
                raise RuntimeError(f"FluxDown {method} failed: {response['error']}")
            return response["result"]

    try:
        call(1, "system.hello", {
            "clientName": "home-manager-stylix",
            "clientVersion": "1",
            "minProtocolVersion": 10,
            "maxProtocolVersion": 10,
            "requestedRole": "agent",
            "capabilities": [],
        })
        result = call(2, "agent.preferences.patch", {"values": {
            "appearance.custom_themes.stylix": theme,
            f"appearance.{mode}_theme": "custom:stylix",
            "appearance.theme_mode": mode,
        }})
        if not result["ok"]:
            raise RuntimeError("FluxDown rejected the Stylix theme preferences")
        print(f"FluxDown: imported and selected Stylix ({mode})", flush=True)
    finally:
        socket.close()


if __name__ == "__main__":
    try:
        apply_theme(sys.argv[1], sys.argv[2])
    except Exception as error:
        print(f"FluxDown Stylix import failed: {error}", file=sys.stderr)
        sys.exit(1)
