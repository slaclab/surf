##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

from contextlib import contextmanager
from dataclasses import dataclass
import json
import os
from pathlib import Path
import subprocess
import sys
import time


PEER_SCRIPT = Path(__file__).with_name("rogue_tcp_peer.py")


def terminate_process(process, timeout_seconds=5):
    if process.poll() is not None:
        return
    process.terminate()
    try:
        process.wait(timeout=timeout_seconds)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=timeout_seconds)


@dataclass
class PeerProcess:
    mode: str
    tag: int
    port: int
    result_path: Path
    ready_path: Path | None
    process: subprocess.Popen

    @property
    def returncode(self):
        return self.process.returncode

    def poll(self):
        return self.process.poll()

    def wait(self, timeout_seconds):
        return self.process.wait(timeout=timeout_seconds)

    def terminate(self, timeout_seconds=5):
        terminate_process(self.process, timeout_seconds)

    def read_result(self):
        return json.loads(self.result_path.read_text())


def spawn_peer(
    mode,
    port,
    result_path,
    *,
    tag=0,
    ready_path=None,
    env=None,
):
    result_path = Path(result_path)
    ready_path = Path(ready_path) if ready_path is not None else None
    result_path.parent.mkdir(parents=True, exist_ok=True)
    result_path.unlink(missing_ok=True)
    if ready_path is not None:
        ready_path.parent.mkdir(parents=True, exist_ok=True)
        ready_path.unlink(missing_ok=True)

    command = [
        sys.executable,
        str(PEER_SCRIPT),
        "--mode",
        mode,
        "--tag",
        str(tag),
    ]
    if ready_path is not None:
        command.extend(("--ready-file", str(ready_path)))
    command.extend((str(port), str(result_path)))

    process = subprocess.Popen(
        command,
        env=None if env is None else {**os.environ, **env},
    )
    return PeerProcess(mode, tag, port, result_path, ready_path, process)


@contextmanager
def managed_peer(*args, **kwargs):
    peer = spawn_peer(*args, **kwargs)
    try:
        yield peer
    finally:
        peer.terminate()


def spawn_peer_group(specs, result_dir, *, ready=False, env=None):
    result_dir = Path(result_dir)
    peers = []
    for mode, tag, port in specs:
        stem = f"{mode}-{tag}-{port}"
        peers.append(spawn_peer(
            mode,
            port,
            result_dir / f"{stem}.json",
            tag=tag,
            ready_path=(result_dir / f"{stem}.ready") if ready else None,
            env=env,
        ))
    return peers


def terminate_peers(peers):
    for peer in peers:
        peer.terminate()


def wait_for_peers_ready(peers, timeout_seconds):
    deadline = time.monotonic() + timeout_seconds
    while time.monotonic() < deadline:
        failed = [
            (peer.mode, peer.tag, peer.returncode)
            for peer in peers
            if peer.poll() is not None
        ]
        if failed:
            raise AssertionError(f"peer exited before readiness: {failed}")
        if all(
            peer.ready_path is not None and peer.ready_path.exists()
            for peer in peers
        ):
            return
        time.sleep(0.01)
    pending = [
        (peer.mode, peer.tag, peer.port)
        for peer in peers
        if peer.ready_path is None or not peer.ready_path.exists()
    ]
    raise TimeoutError(
        f"peers did not signal readiness within {timeout_seconds}s: {pending}"
    )
