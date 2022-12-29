# dartzmq_example

For the example to work you will need some kind of backend that replies to the `REQ` socket that is created in the flutter application.
The easiest way is using the following python script, which will act as a server that just replies with the same message sent to it.
Also don't forget to install `pyzmq` with `pip install pyzmq`.
```python
import zmq

context = zmq.Context()
socket = context.socket(zmq.REP)
socket.bind("tcp://*:5566")

while True:
    #  Wait for next request from client
    message = socket.recv()
    print("Received request: %s" % message)

    #  Send reply back to client
    socket.send(message)
```

## Further helpful resources

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
