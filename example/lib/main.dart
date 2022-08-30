import 'dart:async';

import 'package:dartzmq/dartzmq.dart';
import 'package:flutter/material.dart';

/// !IMPORTANT! If you are not running the example on Windows or Android
/// dont't forget to copy your shared library (.dll, .so or .dylib) to the executable path
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final ZContext _context = ZContext();
  late final ZSocket _socket;
  String _receivedData = '';
  late StreamSubscription _subscription;
  int _presses = 0;

  @override
  void initState() {
    _socket = _context.createSocket(SocketType.req);
    _socket.connect("tcp://localhost:5566");
    // host ip address in android simulator is 10.0.2.2
    // _socket.connect("tcp://10.0.2.2:5566");
    // _socket.connect("tcp://192.168.2.18:5566");

    // listen for messages
    _subscription = _socket.messages.listen((message) {
      setState(() {
        _receivedData = message.toString();
      });
    });

    // listen for frames
    // _subscription = _socket.frames.listen((frame) {
    //   setState(() {
    //     _receivedData = frame.toString();
    //   });
    // });

    // listen for payloads
    // _subscription = _socket.payloads.listen((payload) {
    //   setState(() {
    //     _receivedData = payload.toString();
    //   });
    // });
    super.initState();
  }

  @override
  void dispose() {
    _socket.close();
    _context.stop();
    _subscription.cancel();
    super.dispose();
  }

  void _sendMessage() {
    ++_presses;
    _socket.send([_presses]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("dartzmq demo"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('Press to send a message'),
            MaterialButton(
              onPressed: _sendMessage,
              color: Colors.blue,
              child: const Text('Send'),
            ),
            const Text('Received'),
            Text(_receivedData),
          ],
        ),
      ),
    );
  }
}
