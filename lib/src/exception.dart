part of dartzmq;

/// Custom Exception type for ZeroMQ specific exceptions
class ZeroMQException implements Exception {
  final int errorCode;

  ZeroMQException(this.errorCode);

  @override
  String toString() {
    final msg = _errorMessages[errorCode];
    if (msg == null) {
      return 'ZeroMQException($errorCode)';
    } else {
      return 'ZeroMQException($errorCode): $msg';
    }
  }

  /// Maps error codes to messages
  static const Map<int, String> _errorMessages = {
    // errno
    EINTR: 'EINTR: The operation was interrupted',
    EBADF: 'EBADF: Bad file descriptor',
    EAGAIN: 'EAGAIN', // denpendant on what function has been called before
    EACCES: 'EACCES: Permission denied',
    EFAULT: 'EFAULT', // denpendant on what function has been called before
    EINVAL: 'EINVAL', // denpendant on what function has been called before
    EMFILE: 'EMFILE', // denpendant on what function has been called before

    // 0MQ errors
    ENOTSUP: 'Not supported',
    EPROTONOSUPPORT: 'Protocol not supported',
    ENOBUFS: 'No buffer space available',
    ENETDOWN: 'Network is down',
    EADDRINUSE: 'Address in use',
    EADDRNOTAVAIL: 'Address not available',
    ECONNREFUSED: 'Connection refused',
    EINPROGRESS: 'Operation in progress',
    EFSM: 'Operation cannot be accomplished in current state',
    ENOCOMPATPROTO: 'The protocol is not compatible with the socket type',
    ETERM: 'Context was terminated',
    EMTHREAD: 'No thread available',
    EHOSTUNREACH: 'Host unreachable',
  };
}

void _checkReturnCode(int code, {List<int> ignore = const []}) {
  if (code < 0) {
    _checkErrorCode(ignore: ignore);
  }
}

void _checkErrorCode({List<int> ignore = const []}) {
  final errorCode = _bindings.zmq_errno();
  if (!ignore.contains(errorCode)) {
    throw ZeroMQException(errorCode);
  }
}
