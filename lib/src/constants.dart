// ignore_for_file: constant_identifier_names

part of 'zeromq.dart';

// Constants, https://github.com/zeromq/libzmq/blob/9bb6b2142385b78d47811b73745b9c21ec366106/include/zmq.h#L285-L301

// Socket types
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

// Poller
const int ZMQ_POLLIN = 1;
const int ZMQ_POLLOUT = 2;
const int ZMQ_POLLERR = 4;
const int ZMQ_POLLPRI = 8;

// Send/recv Options
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
const int ZMQ_ROUTER_HANDOVER = 56;
const int ZMQ_TOS = 57;
const int ZMQ_CONNECT_ROUTING_ID = 61;
const int ZMQ_GSSAPI_SERVER = 62;
const int ZMQ_GSSAPI_PRINCIPAL = 63;
const int ZMQ_GSSAPI_SERVICE_PRINCIPAL = 64;
const int ZMQ_GSSAPI_PLAINTEXT = 65;
const int ZMQ_HANDSHAKE_IVL = 66;
const int ZMQ_SOCKS_PROXY = 68;
const int ZMQ_XPUB_NODROP = 69;
const int ZMQ_BLOCKY = 70;
const int ZMQ_XPUB_MANUAL = 71;
const int ZMQ_XPUB_WELCOME_MSG = 72;
const int ZMQ_STREAM_NOTIFY = 73;
const int ZMQ_INVERT_MATCHING = 74;
const int ZMQ_HEARTBEAT_IVL = 75;
const int ZMQ_HEARTBEAT_TTL = 76;
const int ZMQ_HEARTBEAT_TIMEOUT = 77;
const int ZMQ_XPUB_VERBOSER = 78;
const int ZMQ_CONNECT_TIMEOUT = 79;
const int ZMQ_TCP_MAXRT = 80;
const int ZMQ_THREAD_SAFE = 81;
const int ZMQ_MULTICAST_MAXTPDU = 84;
const int ZMQ_VMCI_BUFFER_SIZE = 85;
const int ZMQ_VMCI_BUFFER_MIN_SIZE = 86;
const int ZMQ_VMCI_BUFFER_MAX_SIZE = 87;
const int ZMQ_VMCI_CONNECT_TIMEOUT = 88;
const int ZMQ_USE_FD = 89;
const int ZMQ_GSSAPI_PRINCIPAL_NAMETYPE = 90;
const int ZMQ_GSSAPI_SERVICE_PRINCIPAL_NAMETYPE = 91;
const int ZMQ_BINDTODEVICE = 92;

// 0MQ errors
// https://github.com/zeromq/libzmq/blob/9bb6b2142385b78d47811b73745b9c21ec366106/include/zmq.h#L133
const int ZMQ_HAUSNUMERO = 156384712;

const int ENOTSUP = ZMQ_HAUSNUMERO + 1;
const int EPROTONOSUPPORT = ZMQ_HAUSNUMERO + 2;
const int ENOBUFS = ZMQ_HAUSNUMERO + 3;
const int ENETDOWN = ZMQ_HAUSNUMERO + 4;
const int EADDRINUSE = ZMQ_HAUSNUMERO + 5;
const int EADDRNOTAVAIL = ZMQ_HAUSNUMERO + 6;
const int ECONNREFUSED = ZMQ_HAUSNUMERO + 7;
const int EINPROGRESS = ZMQ_HAUSNUMERO + 8;
const int ENOTSOCK = ZMQ_HAUSNUMERO + 9;
const int EMSGSIZE = ZMQ_HAUSNUMERO + 10;
const int EAFNOSUPPORT = ZMQ_HAUSNUMERO + 11;
const int ENETUNREACH = ZMQ_HAUSNUMERO + 12;
const int ECONNABORTED = ZMQ_HAUSNUMERO + 13;
const int ECONNRESET = ZMQ_HAUSNUMERO + 14;
const int ENOTCONN = ZMQ_HAUSNUMERO + 15;
const int ETIMEDOUT = ZMQ_HAUSNUMERO + 16;
const int EHOSTUNREACH = ZMQ_HAUSNUMERO + 17;
const int ENETRESET = ZMQ_HAUSNUMERO + 18;

// Native 0MQ error codes
const int EFSM = ZMQ_HAUSNUMERO + 51;
const int ENOCOMPATPROTO = ZMQ_HAUSNUMERO + 52;
const int ETERM = ZMQ_HAUSNUMERO + 53;
const int EMTHREAD = ZMQ_HAUSNUMERO + 54;

// errno
const int EINTR = 4;
const int EBADF = 9;
const int EAGAIN = 11;
const int EACCES = 13;
const int EFAULT = 14;
const int EINVAL = 22;
const int EMFILE = 24;

// Socket events
const int ZMQ_EVENT_CONNECTED = 0x0001;
const int ZMQ_EVENT_CONNECT_DELAYED = 0x0002;
const int ZMQ_EVENT_CONNECT_RETRIED = 0x0004;
const int ZMQ_EVENT_LISTENING = 0x0008;
const int ZMQ_EVENT_BIND_FAILED = 0x0010;
const int ZMQ_EVENT_ACCEPTED = 0x0020;
const int ZMQ_EVENT_ACCEPT_FAILED = 0x0040;
const int ZMQ_EVENT_CLOSED = 0x0080;
const int ZMQ_EVENT_CLOSE_FAILED = 0x0100;
const int ZMQ_EVENT_DISCONNECTED = 0x0200;
const int ZMQ_EVENT_MONITOR_STOPPED = 0x0400;
const int ZMQ_EVENT_ALL = 0xFFFF;

/*  Unspecified system errors during handshake. Event value is an errno.      */
const int ZMQ_EVENT_HANDSHAKE_FAILED_NO_DETAIL = 0x0800;
/*  Handshake complete successfully with successful authentication (if        *
 *  enabled). Event value is unused.                                          */
const int ZMQ_EVENT_HANDSHAKE_SUCCEEDED = 0x1000;
/*  Protocol errors between ZMTP peers or between server and ZAP handler.     *
 *  Event value is one of ZMQ_PROTOCOL_ERROR_*                                */
const int ZMQ_EVENT_HANDSHAKE_FAILED_PROTOCOL = 0x2000;
/*  Failed authentication requests. Event value is the numeric ZAP status     *
 *  code, i.e. 300, 400 or 500.                                               */
const int ZMQ_EVENT_HANDSHAKE_FAILED_AUTH = 0x4000;
