## 1.0.0-dev.4

### Fix heap corruption due to wrong usage of `malloc.allocate`
- Use periodic timer to poll sockets every second
- Poll all messages on socket instead of one for each event to not loose messages
- Reuse zeromq message pointer
- Improve return code handling
- Rename `_isActive` of `ZContext` to `_shutdown`
- Rename `_handle` and `_zmq` of `ZSocket` to `_socket` and `_context`
- Add stream for `ZFrames` to `ZSocket`
- Always show error code in `ZeroMQException`
- Fix pubspec of example


## 1.0.0-dev.3

### Add example, subscriptions for `sub` sockets and code cleanup
- Add minimal working example
- Rename `ZmqSocket` to `ZSocket`
- Rename `ZeroMQ` to `ZContext`
- Rename `ZeroMQBindings` tor `ZMQBindings`
- Add `subscribe(String topic)` and `unsubscribe(String topic)` to manage subscriptions of `sub` sockets


## 1.0.0-dev.2

### Add support for multipart messages
- Rename `Message` to `ZFrame`
- Add `ZMessage` as a queue of `ZFrame`'s
- Receive messages as `ZMessage` instead of `Message`(`ZFrame`)
- Reduce minimum SDK version to `2.13.0`


## 1.0.0-dev.1

### Add crude implementation of libzmq
- Creating sockets (pair,  pub,  sub,  req,  rep,  dealer,  router,  pull,  push,  xPub,  xSub,  stream)
- Sending messages (of type `List<int>`)
- Bind (`bind(String address)`)
- Connect (`connect(String address)`)
- Curve (`setCurvePublicKey(String key)`, `setCurveSecretKey(String key)` and `setCurveServerKey(String key)`)
- Socket options (`setOption(int option, String value)`)