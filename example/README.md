# dartzmq_example

For the example to work you will need some kind of backend that replies to the `REQ` socket that is created in the flutter application.
The easiest way is using the following python script, which will act as a server that just replies with the same message sent to it.
Also don't forget to install `pyzmq` with `pip install pyzmq`.
```python
#!/usr/bin/env python

import zmq


def main():
    context = zmq.Context()
    poller = zmq.Poller()
    socket = context.socket(zmq.ROUTER)

    address = "tcp://*:{}".format(5566)
    socket.bind(address)

    poller.register(socket, zmq.POLLIN)

    print("Running...")
    try:
        while True:
            items = dict(poller.poll(zmq.NOBLOCK))
            for sock in items:
                try:
                    msg = sock.recv_multipart(zmq.NOBLOCK)
                    print("I: %r" % (msg))
                    reply = msg + ['ECHO'.encode()]
                    print("O: %r" % (reply))
                    sock.send_multipart(reply)
                except:
                    print("Could not read socket")
                    pass
    finally:
        socket.unbind(address)  # ALWAYS RELEASE PORT
        socket.close()  # ALWAYS RELEASE RESOURCES
        context.term()  # ALWAYS RELEASE RESOURCES


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("Done")
        pass

```

## Further helpful resources

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
