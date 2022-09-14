part of dartzmq;

/// A ZFrame or 'frame' corresponds to one underlying zmq_msg_t in the libzmq code.
/// When you read a frame from a socket, the [hasMore] member indicates
/// if the frame is part of an unfinished multi-part message.
class ZFrame {
  /// The payload that was received or is to be sent
  final Uint8List payload;

  /// Is this frame part of an unfinished multi-part message?
  final bool hasMore;

  ZFrame(this.payload, {this.hasMore = false});

  @override
  String toString() => 'ZFrame[$payload]';
}

/// ZMessage provides a list-like container interface,
/// with methods to work with the overall container. ZMessage messages are
/// composed of zero or more ZFrame objects.
// typedef ZMessage = Queue<ZFrame>;
class ZMessage implements Queue<ZFrame> {
  final DoubleLinkedQueue<ZFrame> _frames = DoubleLinkedQueue();

  @override
  Iterator<ZFrame> get iterator => _frames.iterator;

  @override
  void add(ZFrame value) => _frames.add(value);

  @override
  void addAll(Iterable<ZFrame> iterable) => _frames.addAll(iterable);

  @override
  void addFirst(ZFrame value) => _frames.addFirst(value);

  @override
  void addLast(ZFrame value) => _frames.addLast(value);

  @override
  void clear() => _frames.clear();

  @override
  bool remove(Object? value) => _frames.remove(value);

  @override
  ZFrame removeFirst() => _frames.removeFirst();

  @override
  ZFrame removeLast() => _frames.removeLast();

  @override
  void removeWhere(bool Function(ZFrame element) test) =>
      _frames.removeWhere(test);

  @override
  void retainWhere(bool Function(ZFrame element) test) =>
      _frames.retainWhere(test);

  @override
  bool any(bool Function(ZFrame element) test) => _frames.any(test);

  @override
  Queue<R> cast<R>() => _frames.cast<R>();

  @override
  bool contains(Object? element) => _frames.contains(element);

  @override
  ZFrame elementAt(int index) => _frames.elementAt(index);

  @override
  bool every(bool Function(ZFrame element) test) => _frames.every(test);

  @override
  Iterable<T> expand<T>(Iterable<T> Function(ZFrame element) toElements) =>
      _frames.expand(toElements);

  @override
  ZFrame get first => _frames.first;

  @override
  ZFrame firstWhere(bool Function(ZFrame element) test,
          {ZFrame Function()? orElse}) =>
      _frames.firstWhere(test, orElse: orElse);

  @override
  T fold<T>(T initialValue,
          T Function(T previousValue, ZFrame element) combine) =>
      _frames.fold(initialValue, combine);

  @override
  Iterable<ZFrame> followedBy(Iterable<ZFrame> other) =>
      _frames.followedBy(other);

  @override
  void forEach(void Function(ZFrame element) action) => _frames.forEach(action);

  @override
  bool get isEmpty => _frames.isEmpty;

  @override
  bool get isNotEmpty => _frames.isNotEmpty;

  @override
  String join([String separator = '']) => _frames.join(separator);

  @override
  ZFrame get last => _frames.last;

  @override
  ZFrame lastWhere(bool Function(ZFrame element) test,
          {ZFrame Function()? orElse}) =>
      _frames.lastWhere(test, orElse: orElse);

  @override
  int get length => _frames.length;

  @override
  Iterable<T> map<T>(T Function(ZFrame e) toElement) => _frames.map(toElement);

  @override
  ZFrame reduce(ZFrame Function(ZFrame value, ZFrame element) combine) =>
      _frames.reduce(combine);

  @override
  ZFrame get single => _frames.single;

  @override
  ZFrame singleWhere(bool Function(ZFrame element) test,
          {ZFrame Function()? orElse}) =>
      _frames.singleWhere(test, orElse: orElse);

  @override
  Iterable<ZFrame> skip(int count) => _frames.skip(count);

  @override
  Iterable<ZFrame> skipWhile(bool Function(ZFrame value) test) =>
      _frames.skipWhile(test);

  @override
  Iterable<ZFrame> take(int count) => _frames.take(count);

  @override
  Iterable<ZFrame> takeWhile(bool Function(ZFrame value) test) =>
      _frames.takeWhile(test);

  @override
  List<ZFrame> toList({bool growable = true}) =>
      _frames.toList(growable: growable);

  @override
  Set<ZFrame> toSet() => _frames.toSet();

  @override
  Iterable<ZFrame> where(bool Function(ZFrame element) test) =>
      _frames.where(test);

  @override
  Iterable<T> whereType<T>() => _frames.whereType<T>();

  @override
  String toString() =>
      IterableBase.iterableToFullString(this, 'ZMessage[', ']');
}
