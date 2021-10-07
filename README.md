# dartzmq
A simple dart zeromq implementation/wrapper around the libzmq C++ library

## Features
Currently supported:
- Creating sockets (pair,  pub,  sub,  req,  rep,  dealer,  router,  pull,  push,  xPub,  xSub,  stream)
- Sending messages (of type `List<int>`)
- Bind (`bind(String address)`)
- Connect (`connect(String address)`)
- Curve (`setCurvePublicKey(String key)`, `setCurveSecretKey(String key)` and `setCurveServerKey(String key)`)
- Socket options (`setOption(int option, String value)`)

## Getting started
Currently only windows is officially supported as a platform, but it depends on the used shared library of `libzmq`.
I have tested this on windows, which works. 
Other platforms have not been tested, but should work. 
If you have tested this plugin on another platform and got it to work, please share your findings and create an issue to add it to the list.

Once you installed this plugin place the shared library of `libzmq` next to your executable (for example place `libzmq-v142-mt-4_3_5.dll` in the folder `yourproject/build/windows/runner/Debug/`)

> Note that in order for this plugin to work you will need to either get a shared library of `libzmq` or compile it yourself. 
> Especially when using this on windows you need to make sure that `libzmq` is compiled using `MSVC-2019` if you are using `clang` it will not work ([more info](https://flutterforum.co/t/windows-desktop-flutter-ffi-and-loading-the-clang-library/3842))

## Usage

TODO: Include short and useful examples for package users. Add longer examples
to `/example` folder. 

```dart
const like = 'sample';
```

## Additional information

TODO: Tell users more about the package: where to find more information, how to 
contribute to the package, how to file issues, what response they can expect 
from the package authors, and more.
