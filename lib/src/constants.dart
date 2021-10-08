// ignore_for_file: constant_identifier_names
part of 'bindings.dart';

// Constants, https://github.com/zeromq/libzmq/blob/9bb6b2142385b78d47811b73745b9c21ec366106/include/zmq.h#L285-L301

const int ZMQ_PAIR = 0;
const int ZMQ_PUB = 1;
const int ZMQ_SUB = 2;
const int ZMQ_REQ = 3;
const int ZMQ_REP = 4;
const int ZMQ_DEALER = 5;
const int ZMQ_ROUTER = 6;
const int ZMQ_PULL = 7;
const int ZMQ_PUSH = 8;
const int ZMQ_XPUB = 9;
const int ZMQ_XSUB = 10;
const int ZMQ_STREAM = 11;

const int ZMQ_POLLIN = 1;
const int ZMQ_POLLOUT = 2;
const int ZMQ_POLLERR = 4;
const int ZMQ_POLLPRI = 8;

const int ZMQ_DONTWAIT = 1;
const int ZMQ_SNDMORE = 2;

// Socket Options
const int ZMQ_AFFINITY = 4;
const int ZMQ_IDENTITY = 5;
const int ZMQ_SUBSCRIBE = 6;
const int ZMQ_UNSUBSCRIBE = 7;
const int ZMQ_RATE = 8;
const int ZMQ_RECOVERY_IVL = 9;
const int ZMQ_SNDBUF = 11;
const int ZMQ_RCVBUF = 12;
const int ZMQ_RCVMORE = 13;
const int ZMQ_FD = 14;
const int ZMQ_EVENTS = 15;
const int ZMQ_TYPE = 16;
const int ZMQ_LINGER = 17;
const int ZMQ_RECONNECT_IVL = 18;
const int ZMQ_BACKLOG = 19;
const int ZMQ_RECONNECT_IVL_MAX = 21;
const int ZMQ_MAXMSGSIZE = 22;
const int ZMQ_SNDHWM = 23;
const int ZMQ_RCVHWM = 24;
const int ZMQ_MULTICAST_HOPS = 25;
const int ZMQ_RCVTIMEO = 27;
const int ZMQ_SNDTIMEO = 28;
const int ZMQ_LAST_ENDPOINT = 32;
const int ZMQ_ROUTER_MANDATORY = 33;
const int ZMQ_TCP_KEEPALIVE = 34;
const int ZMQ_TCP_KEEPALIVE_CNT = 35;
const int ZMQ_TCP_KEEPALIVE_IDLE = 36;
const int ZMQ_TCP_KEEPALIVE_INTVL = 37;
const int ZMQ_XPUB_VERBOSE = 40;
const int ZMQ_ROUTER_RAW = 41;
const int ZMQ_IPV6 = 42;
const int ZMQ_MECHANISM = 43;
const int ZMQ_PLAIN_SERVER = 44;
const int ZMQ_PLAIN_USERNAME = 45;
const int ZMQ_PLAIN_PASSWORD = 46;
const int ZMQ_CURVE_SERVER = 47;
const int ZMQ_CURVE_PUBLICKEY = 48;
const int ZMQ_CURVE_SECRETKEY = 49;
const int ZMQ_CURVE_SERVERKEY = 50;
const int ZMQ_PROBE_ROUTER = 51;
const int ZMQ_REQ_CORRELATE = 52;
const int ZMQ_REQ_RELAXED = 53;
const int ZMQ_CONFLATE = 54;
const int ZMQ_ZAP_DOMAIN = 55;

// https://github.com/zeromq/libzmq/blob/9bb6b2142385b78d47811b73745b9c21ec366106/include/zmq.h#L133
const int _errorBase = 156384712;

const int ENOTSUP = _errorBase + 1;
const int EPROTONOSUPPORT = _errorBase + 2;
const int ENOBUFS = _errorBase + 3;
const int ENETDOWN = _errorBase + 4;
const int EADDRINUSE = _errorBase + 5;
const int EADDRNOTAVAIL = _errorBase + 6;
const int ECONNREFUSED = _errorBase + 7;
const int EINPROGRESS = _errorBase + 8;
const int ENOTSOCK = _errorBase + 9;
const int EMSGSIZE = _errorBase + 10;
const int EAFNOSUPPORT = _errorBase + 11;
const int ENETUNREACH = _errorBase + 12;
const int ECONNABORTED = _errorBase + 13;
const int ECONNRESET = _errorBase + 14;
const int ENOTCONN = _errorBase + 15;
const int ETIMEDOUT = _errorBase + 16;
const int EHOSTUNREACH = _errorBase + 17;
const int ENETRESET = _errorBase + 18;
