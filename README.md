# dartzmq
A simple dart zeromq implementation/wrapper around the libzmq C++ library


## Features
Currently supported:
- Creating sockets (`pair`,  `pub`,  `sub`,  `req`,  `rep`,  `dealer`,  `router`,  `pull`,  `push`,  `xPub`,  `xSub`,  `stream`)
- Sending messages (of type `List<int>`)
- Bind (`bind(String address)`)
- Connect (`connect(String address)`)
- Curve (`setCurvePublicKey(String key)`, `setCurveSecretKey(String key)` and `setCurveServerKey(String key)`)
- Socket options (`setOption(int option, String value)`)
- Receiving multipart messages (`ZMessage`)
- Topic subscription for `sub` sockets (`subscribe(String topic)` & `unsubscribe(String topic)`)


## Getting started
Currently Windows and Android are officially supported as platforms, but it depends on the used shared library of `libzmq`.
I have tested this on Windows and Android, which work. 
Other platforms have not been tested, but should work. 
If you have tested this plugin on another platform and got it to work, please share your steps and create an issue so I can add it to the list below.

### Windows
Place a shared library of `libzmq` next to your executable (for example place `libzmq-v142-mt-4_3_5.dll` in the folder `yourproject/build/windows/runner/Debug/`)

> Note that in order for this plugin to work you will need to either get a shared library of `libzmq` or compile it yourself. 
> Especially when using this on windows you need to make sure that `libzmq` is compiled using `MSVC-2019` if you are using `clang` it will not work ([more info](https://flutterforum.co/t/windows-desktop-flutter-ffi-and-loading-the-clang-library/3842))

### Android
> Note that you need to use Android NDK version r21d. Newer versions are currently not supported (see https://github.com/zeromq/libzmq/issues/4276)

1. Follow [these steps](https://github.com/zeromq/libzmq/tree/master/builds/android) to build a `libzmq.so` for different platforms
   - If you need `curve` support make sure to set the environment variable `CURVE` either to `export CURVE=libsodium` or `export CURVE=tweetnacl` before running the build command
2. Include these in your project following [these steps](https://github.com/truongsinh/flutter-ffi-samples/blob/master/packages/sqlite/docs/android.md#update-gradle-script)
3. Include the compiled standard c++ library `libc++_shared.so` files located inside the Android NDK as in step 2 ([reference](https://developer.android.com/ndk/guides/cpp-support#cs))
   - You can find these inside the Android NDK for example under this path `ndk\21.4.7075529\toolchains\llvm\prebuilt\windows-x86_64\sysroot\usr\lib`


## Usage
Create context
```dart
final ZContext context = ZContext();
```

Create socket
```dart
final ZSocket socket = context.createSocket(SocketType.req);
```

Connect socket
```dart
socket.connect("tcp://localhost:5566");
```

Send message
```dart
socket.send([1, 2, 3, 4, 5]);
```

Receive `ZMessage`s
```dart
_socket.messages.listen((message) {
    // Do something with message
});
```

Receive `ZFrame`s
```dart
_socket.frames.listen((frame) {
    // Do something with frame
});
```

Receive payloads (`Uint8List`)
```dart
_socket.payloads.listen((payload) {
    // Do something with payload
});
```

Destroy socket
```dart
socket.close();
```

Destroy context
```dart
context.stop();
```


<!-- ## Additional information
TODO: Tell users more about the package: where to find more information, how to 
contribute to the package, how to file issues, what response they can expect 
from the package authors, and more. -->
