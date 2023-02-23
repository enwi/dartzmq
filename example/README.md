# dartzmq_example

For the example to work you will need some kind of backend that replies to the `REQ` socket that is created in the flutter application.
The easiest way is using the following python script, which will act as a server that just replies with the same message sent to it.
Also don't forget to install `pyzmq` with `pip install pyzmq`.
```python
#!/usr/bin/env python

import sys
import zmq

context = zmq.Context()
poller = zmq.Poller()
socket = context.socket(zmq.REP)

socket.bind("tcp://*:5566")

poller.register(socket, zmq.POLLIN)

print("Running...")
while True:
    items = dict(poller.poll())
    for sock in items:
        msg = sock.recv_multipart()
        print("I: %r" % (msg))
        reply = ['ECHO'.encode()] + msg
        print("O: %r" % (reply))
        sock.send_multipart(reply)
```

## Further helpful resources

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
