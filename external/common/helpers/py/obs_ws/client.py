"""Minimal obs-websocket v5 client for one-shot requests.

Assumes OBS has websocket authentication disabled.
"""

import json
import uuid
from typing import Any

from websockets.sync.client import connect

RPC_VERSION = 1

_OP_IDENTIFY = 1
_OP_IDENTIFIED = 2
_OP_REQUEST = 6
_OP_RESPONSE = 7

_NO_EVENTS = 0


class ObsWebSocketError(RuntimeError):
    """OBS reached, but the handshake or the request was rejected."""


def obs_request(
    host: str,
    port: int,
    request_type: str,
    request_data: dict[str, Any] | None = None,
    *,
    timeout: float = 3.0,
) -> dict[str, Any]:
    """Open a connection, identify, send one request and return its responseData."""
    with connect(f"ws://{host}:{port}", open_timeout=timeout) as ws:
        hello = json.loads(ws.recv(timeout))
        if hello["d"].get("authentication"):
            msg = (
                "OBS websocket has a password set, but this client does not "
                "support auth: disable it in OBS (Tools > WebSocket Server Settings)"
            )
            raise ObsWebSocketError(msg)
        identify = {"rpcVersion": RPC_VERSION, "eventSubscriptions": _NO_EVENTS}
        ws.send(json.dumps({"op": _OP_IDENTIFY, "d": identify}))

        identified = json.loads(ws.recv(timeout))
        if identified.get("op") != _OP_IDENTIFIED:
            msg = f"identify rejected: {identified}"
            raise ObsWebSocketError(msg)

        request_id = str(uuid.uuid4())
        ws.send(
            json.dumps(
                {
                    "op": _OP_REQUEST,
                    "d": {
                        "requestType": request_type,
                        "requestId": request_id,
                        "requestData": request_data or {},
                    },
                }
            )
        )
        while True:
            msg = json.loads(ws.recv(timeout))
            if msg.get("op") != _OP_RESPONSE or msg["d"]["requestId"] != request_id:
                continue
            status = msg["d"]["requestStatus"]
            if not status["result"]:
                comment = status.get("comment", "")
                err = f"{request_type} failed ({status['code']}): {comment}"
                raise ObsWebSocketError(err)
            return msg["d"].get("responseData") or {}


def refresh_browser_source(
    host: str,
    port: int,
    input_name: str,
    *,
    timeout: float = 3.0,
) -> None:
    """Refresh a browser source in OBS via ws, using its unique name."""
    obs_request(
        host,
        port,
        "PressInputPropertiesButton",
        {"inputName": input_name, "propertyName": "refreshnocache"},
        timeout=timeout,
    )
