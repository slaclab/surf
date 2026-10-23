##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

# Shared ZeroMQ socket construction for the SimLink test peers and native
# probes. Every SimLink test socket sets LINGER=0 (so teardown never blocks on
# undelivered frames) and, when it talks to a model, a finite receive timeout
# (so a stuck peer fails the test instead of hanging). This helper centralizes
# that boilerplate; callers pass only what varies (socket type, endpoint,
# timeout, high-water mark).

import zmq

# Matches the previous per-file defaults so behavior is unchanged.
DEFAULT_RCVTIMEO_MS = 5000


def make_socket(
    context,
    socket_type,
    *,
    endpoint=None,
    rcvtimeo_ms=None,
    receive_hwm=None,
    receive_buf=None,
):
    """Create a LINGER=0 ZeroMQ socket with the common SimLink options.

    endpoint     -- if given, connect() to it before returning.
    rcvtimeo_ms  -- ZMQ_RCVTIMEO in milliseconds; None leaves the default
                    (blocking) receive.
    receive_hwm  -- ZMQ_RCVHWM; None leaves the default.
    receive_buf  -- ZMQ_RCVBUF; None leaves the default.
    """
    socket = context.socket(socket_type)
    socket.setsockopt(zmq.LINGER, 0)
    if rcvtimeo_ms is not None:
        socket.setsockopt(zmq.RCVTIMEO, rcvtimeo_ms)
    if receive_hwm is not None:
        socket.setsockopt(zmq.RCVHWM, receive_hwm)
    if receive_buf is not None:
        socket.setsockopt(zmq.RCVBUF, receive_buf)
    if endpoint is not None:
        socket.connect(endpoint)
    return socket


def pull_socket(context, port, *, receive_hwm=None):
    """PULL socket connected to 127.0.0.1:<port> with a finite receive timeout.

    When receive_hwm is set, a small ZMQ_RCVBUF is paired with it so overload
    tests can actually exert backpressure.
    """
    return make_socket(
        context,
        zmq.PULL,
        endpoint=f"tcp://127.0.0.1:{port}",
        rcvtimeo_ms=DEFAULT_RCVTIMEO_MS,
        receive_hwm=receive_hwm,
        receive_buf=1024 if receive_hwm is not None else None,
    )
