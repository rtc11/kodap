module jdwp;

import libc;
import std::io;
import std::net;
import std::thread;
import std::core::mem;
import std::collections::map;
import std::collections::list;

distinct Id = inline char[8];
fn long Id.to_long(&self) => decode_long((char[8]*)&self)!!;  

def Into = fn any(Reply*);

struct Jdwp
{
    TcpSocket client;
    int seq;
    List(<char[]>) events;
    Map(<int, any>) replies;
    Map(<int, Into>) intos;
    bool running;
    Poll p;
    bool debug;
}

bitstruct Command : char[11] @bigendian 
{
    uint length: 0..31;
    uint id:     32..63;
    char flags:  64..71;
    char set:    72..79;
    char cmd:    80..87;
}

struct Reply
{
    bitstruct: char[11] @bigendian 
    {
        uint length:     0..31;
        uint id:         32..63;
        uint flags:      64..71;
        uint error_code: 72..87;
    }
    char[?] body;
}

fn Jdwp Jdwp.new() @operator(construct)
{
    Jdwp jdwp;
    jdwp.seq = 0;
    jdwp.connect()!!;
    return jdwp;
}

fn void! Jdwp.connect(&self, String host = "127.0.0.1", uint port = 5005)
{
    self.client = tcp::connect(host, port)!;
    self.client.sock.set_non_blocking(true)!;
    self.p = {
        .socket = self.client.sock,
        .events = net::SUBSCRIBE_READ,
        .revents = 0,
    };
    self.handshake()!;
}

fn void Jdwp.stop(&self) {
    self.running = false;
} 

fn void! Jdwp.handshake(&self) @private
{
    char[14] res;
    char[14] handshake = "JDWP-Handshake";
    if (self.client.write(&handshake)!! != 14) return JdwpErr.SEND_HANDSHAKE?;
}

fn int Jdwp.start_event_loop(&self)
{
    self.running = true;
    while (self.running) {
        CInt result = os::poll((Posix_pollfd*) &self.p, (Posix_nfds_t) 1, (CInt) 500); // timeout 500ms or -1 for infinite
        if (result < 0) os::socket_error()?!!;
        if (self.p.revents) self.poll();
    }
    io::printfn("event loop stopped");
    return 0;
}

fn void Jdwp.poll(&self)
{
    switch (self.p.events) {
        case net::SUBSCRIBE_READ:
            char[1024 * 32] buf;
            usz n = self.client.read(&buf)!!;
            if (n == 1024 * 32) io::printfn("ERROR: event buffer of 1024*32 is too small for size %d");
            if (buf[8] & 0x80) {
                Reply* reply = mem::new_with_padding(Reply, char.sizeof * (n-11));
                mem::copy(reply, &buf[0], n);
                eval_err(reply.error_code)!!;
                if (self.debug) io::printfn("READ: length:%d id:%d flags:%3d error:%d", reply.length, reply.id, reply.flags, reply.error_code);
                if (self.debug) io::printfn("READ: %s", reply.body[:n-11]);

                Into into = self.intos[reply.id]!!;
                self.replies[reply.id] = into(reply);

            } else {
                if(self.debug) io::printfn("EVENT: %s", buf[..n-1]);
                self.events.push(buf[..n-1]);
            }
            
        default: unreachable("unsupported client state");
    }
}

fn void! Jdwp.send(&self, Command cmd, char[] data = {})
{
    char[] packet = array::tconcat((char[11])cmd, data);
    if (self.debug) io::printfn("SEND: %s", packet);
    if (self.client.write(packet)!! != packet.len) return JdwpErr.SEND_COMMAND?;
}

fn void Jdwp.toggle_debug(&self)
{
    self.debug = !self.debug;
    io::printfn("set debug %s", self.debug);
}

fn char! decode_char(char[] data, int* offset)
{
    char c = data[*offset];
    *offset += 1;
    return c;
}

fn int! decode_int(char[] data, int* offset = null)
{
    if (!offset) return JdwpErr.MISSING_OFFSET?;
    if (data.len - *offset < 4) return JdwpErr.INVALID_DATA?;
    int i = bitorder::read(data[*offset..], IntBE);
    *offset += 4;
    return i;
}

fn long! decode_long(char[] data)
{
    if (data.len < 8) return JdwpErr.INVALID_DATA?;
    return bitorder::read(data, LongBE);
}

fn Id! decode_id(char[] data, int* offset = null)
{
    if (!offset) return JdwpErr.MISSING_OFFSET?;
    if (data.len < 8) return JdwpErr.INVALID_DATA?;
    char[8] tmp; 
    for (int t = 0; t < 8; t++) {
        tmp[t] = data[*offset + t];
    }
    *offset += 8;
    return (Id) tmp;
}

fn char[] encode_string(String str)
{
    int str_len = str.len;
    char[4] length_prefix;
    length_prefix[0] = (char)(str_len >> 24) & 0xFF;
    length_prefix[1] = (char)(str_len >> 16) & 0xFF;
    length_prefix[2] = (char)(str_len >> 8)  & 0xFF;
    length_prefix[3] = (char)(str_len)       & 0xFF;
    return array::tconcat(length_prefix, (char[]) str);
}

fn String! decode_string(char[] data, int* offset = null)
{
    if (!offset) return JdwpErr.MISSING_OFFSET?;
    if (data.len < 4) return JdwpErr.INVALID_DATA?;
    int str_len = decode_int(data, offset)!;

    if (data.len >= str_len) {
        String s = (String) data[*offset .. *offset + str_len - 1];
        *offset += str_len; 
        return s;
    }
    io::printfn("data.len %d - offset %d == str_len %d", data.len, *offset, str_len);
    return "";
}

fault JdwpErr {
    SEND_HANDSHAKE,
    RECV_HANDSHAKE,
    DIFF_HANDSHAKE,
    SEND_COMMAND,
    READ_HEADER,
    READ_DATA,
    INVALID_DATA,
    NOT_FOUND,
    MISSING_OFFSET,
}

fn void! eval_err(int code)
{
    switch (code)
    {
        case 0:   return;
        case 10:  return ErrorCode.INVALID_THREAD?;
        case 11:  return ErrorCode.INVALID_THREAD_GROUP?;
        case 12:  return ErrorCode.INVALID_PRIORITY?;
        case 13:  return ErrorCode.THREAD_NOT_SUSPENDED?;
        case 14:  return ErrorCode.THREAD_SUSPENDED?;
        case 15:  return ErrorCode.THREAD_NOT_ALIVE?;
        case 20:  return ErrorCode.INVALID_OBJECT?;
        case 21:  return ErrorCode.INVALID_CLASS?;
        case 22:  return ErrorCode.CLASS_NOT_PREPARED?;
        case 23:  return ErrorCode.INVALID_METHODID?;
        case 24:  return ErrorCode.INVALID_LOCATION?;
        case 25:  return ErrorCode.INVALID_FIELDID?;
        case 30:  return ErrorCode.INVALID_FRAMEID?;
        case 31:  return ErrorCode.NO_MORE_FRAMES?;
        case 32:  return ErrorCode.OPAQUE_FRAME?;
        case 33:  return ErrorCode.NOT_CURRENT_FRAME?;
        case 34:  return ErrorCode.TYPE_MISMATCH?;
        case 35:  return ErrorCode.INVALID_SLOT?;
        case 40:  return ErrorCode.DUPLICATE?;
        case 41:  return ErrorCode.NOT_FOUND?;
        case 42:  return ErrorCode.INVALID_MODULE?;
        case 50:  return ErrorCode.INVALID_MONITOR?;
        case 51:  return ErrorCode.NOT_MONITOR_OWNER?;
        case 52:  return ErrorCode.INTERRUPT?;
        case 60:  return ErrorCode.INVALID_CLASS_FORMAT?;
        case 61:  return ErrorCode.CIRCULAR_CLASS_DEFINITION?;
        case 62:  return ErrorCode.FAILS_VERIFICATION?;
        case 63:  return ErrorCode.ADD_METHOD_NOT_IMPLEMENTED?;
        case 64:  return ErrorCode.SCHEMA_CHANGE_NOT_IMPLEMENTED?;
        case 65:  return ErrorCode.INVALID_TYPESTATE?;
        case 66:  return ErrorCode.HIERARCHY_CHANGE_NOT_IMPLEMENTED?;
        case 67:  return ErrorCode.DELETE_METHOD_NOT_IMPLEMENTED?;
        case 68:  return ErrorCode.UNSUPPORTED_VERSION?;
        case 69:  return ErrorCode.NAMES_DONT_MATCH?;
        case 70:  return ErrorCode.CLASS_MODIFIERS_CHANGE_NOT_IMPLEMENTED?;
        case 71:  return ErrorCode.METHOD_MODIFIERS_CHANGE_NOT_IMPLEMENTED?;
        case 72:  return ErrorCode.CLASS_ATTRIBUTE_CHANGE_NOT_IMPLEMENTED?;
        case 99:  return ErrorCode.NOT_IMPLEMENTED?;
        case 100: return ErrorCode.NULL_POINTER?;
        case 101: return ErrorCode.ABSENT_INFORMATION?;
        case 102: return ErrorCode.INVALID_EVENT_TYPE?;
        case 103: return ErrorCode.ILLEGAL_ARGUMENT?;
        case 110: return ErrorCode.OUT_OF_MEMORY?;
        case 111: return ErrorCode.ACCESS_DENIED?;
        case 112: return ErrorCode.VM_DEAD?;
        case 113: return ErrorCode.INTERNAL?;
        case 115: return ErrorCode.UNATTACHED_THREAD?;
        case 500: return ErrorCode.INVALID_TAG?;
        case 502: return ErrorCode.ALREADY_INVOKING?;
        case 503: return ErrorCode.INVALID_INDEX?;
        case 504: return ErrorCode.INVALID_LENGTH?;
        case 506: return ErrorCode.INVALID_STRING?;
        case 507: return ErrorCode.INVALID_CLASS_LOADER?;
        case 508: return ErrorCode.INVALID_ARRAY?;
        case 509: return ErrorCode.TRANSPORT_LOAD?;
        case 510: return ErrorCode.TRANSPORT_INIT?;
        case 511: return ErrorCode.NATIVE_METHOD?;
        case 512: return ErrorCode.INVALID_COUNT?;
    }
}

fault ErrorCode
{
    NONE,                                    // no error has occured
    INVALID_THREAD,                          // the thread is null or not a valid thread
    INVALID_THREAD_GROUP,                    // thread group invalid
    INVALID_PRIORITY,                        // invalid priority
    THREAD_NOT_SUSPENDED,                    // if the specified thread has not been suspended by an event
    THREAD_SUSPENDED,                        // thread already suspended
    THREAD_NOT_ALIVE,                        // not used
    INVALID_OBJECT,                          // if this reference type has been unloaded and garbage collected
    INVALID_CLASS,                           // invalid class
    CLASS_NOT_PREPARED,                      // class has been loaded but not yet prepared
    INVALID_METHODID,                        // invalid method
    INVALID_LOCATION,                        // invalid location
    INVALID_FIELDID,                         // invalid field
    INVALID_FRAMEID,                         // invalid jframeID
    NO_MORE_FRAMES,                          // there are no more Java or JNI frames on the call stack
    OPAQUE_FRAME,                            // info about the frame it unavailable (e.g native frame)
    NOT_CURRENT_FRAME,                       // operation can only be performed on current frame
    TYPE_MISMATCH,                           // the variable is not an appropriate type for the function used
    INVALID_SLOT,                            // invalid slot
    DUPLICATE,                               // item already set
    NOT_FOUND,                               // desired element not found
    INVALID_MODULE,                          // invalid module
    INVALID_MONITOR,                         // invalid monitor
    NOT_MONITOR_OWNER,                       // the thread doesnt own the monitor
    INTERRUPT,                               // the call has been interrupted before completion
    INVALID_CLASS_FORMAT,                    // the VM attempted to read a class file and determined that the file is malformed or cannot be interpreded as class file
    CIRCULAR_CLASS_DEFINITION,               // a circularity has been detected while initializing a class
    FAILS_VERIFICATION,                      // the verifier detected that a class file contained som internal inconsitency or security problem
    ADD_METHOD_NOT_IMPLEMENTED,              // adding methods has not been implemneted
    SCHEMA_CHANGE_NOT_IMPLEMENTED,           // schema change has not been implemented
    INVALID_TYPESTATE,                       // the state of the thread has been modified, and is now incosistent
    HIERARCHY_CHANGE_NOT_IMPLEMENTED,        // a direct superclass is different for the new class version or..
    DELETE_METHOD_NOT_IMPLEMENTED,           // the new class version does not declare a method declared in the old class version
    UNSUPPORTED_VERSION,                     // a class file has a version number not supported by this VM
    NAMES_DONT_MATCH,                        // the class name defined in the new class file is different from the name in the old class object
    CLASS_MODIFIERS_CHANGE_NOT_IMPLEMENTED,  // the new class versino has different modifiers and canUnrestrictedlyRedefineClasses is false
    METHOD_MODIFIERS_CHANGE_NOT_IMPLEMENTED, // a method in the new class versino has different modifiers
    CLASS_ATTRIBUTE_CHANGE_NOT_IMPLEMENTED,  // the new class versino has a different NestHost, nestMembers, PermittedSubclasses or Record class attribute
    NOT_IMPLEMENTED,                         // the functionality is not implemented in this VM
    NULL_POINTER,                            // invalid pointer
    ABSENT_INFORMATION,                      // desired informatino is not available
    INVALID_EVENT_TYPE,                      // the specified event type id is not recognized
    ILLEGAL_ARGUMENT,                        // illegal argument
    OUT_OF_MEMORY,                           // the function needed to allocate memory and no more memory was available for allocation
    ACCESS_DENIED,                           // debugging has not been enabled in this VM. JVMTI cannot be used
    VM_DEAD,                                 // the VM is not running
    INTERNAL,                                // an unexpected internal error has occured
    UNATTACHED_THREAD,                       // the thread being used to call this function is not attached to the vm.
    INVALID_TAG,                             // object type id or class tag
    ALREADY_INVOKING,                        // previous invoke not complete
    INVALID_INDEX,                           // index is invalid
    INVALID_LENGTH,                          // the length is invalid
    INVALID_STRING,                          // the string is invalid
    INVALID_CLASS_LOADER,                    // the class loader is invalid
    INVALID_ARRAY,                           // the array is invalid
    TRANSPORT_LOAD,                          // unable to load the transport
    TRANSPORT_INIT,                          // unable to initialize the transport
    NATIVE_METHOD,
    INVALID_COUNT,                           // the count is invalid
}

enum EventKind: (int code)
{
    SINGLE_STEP                   = 1,
    BREAKPOINT                    = 2,
    FRAME_POP                     = 3,
    EXCEPTION                     = 4,
    USER_DEFINED                  = 5,
    THREAD_START                  = 6,
    THREAD_DEATH                  = 7,
    CLASS_PREPARE                 = 8,
    CLASS_UNLOAD                  = 9,
    CLASS_LOAD                    = 10,
    FIELD_ACCESS                  = 20,
    FIELD_MODIFICATION            = 21,
    EXCEPTION_CATCH               = 30,
    METHOD_ENTRY                  = 40,
    METHOD_EXIT                   = 41,
    METHOD_EXIT_WITH_RETURN_VALUE = 42,
    MONITOR_CONTENDED_ENTER       = 43,
    MONITOR_CONTENDED_ENTERED     = 44,
    MONITOR_WAIT                  = 45,
    MONITOR_WAITED                = 46,
    VM_START                      = 90,
    VM_DEATH                      = 99,
    VM_DISCONNECTED               = 100,
}

enum ThreadStatus: (int code)
{
    ZOMBIE   = 0, // thread has terminated
    RUNNING  = 1, // thread is runnable
    SLEEPING = 2, // thread is sleeping, in Thread.sleep
    MONITOR  = 3, // thread is waiting to enter a synchronized block or re-enter a synchronized block
    WAIT     = 4, // thread is waiting. A virtual thread that is sleeping in Thread.sleep may have this thread status instead of SLEEPING
}

enum SuspendStatus: (int code)
{
    SUSPENDED = 0x1
}

enum ClassStatus: (int code)
{
    VERIFIED    = 1,
    PREPARED    = 2,
    INITIALIZED = 4,
    ERROR       = 8,
}

enum TypeTag: (int code)
{
    CLASS     = 1, // ReferenceType is a class
    INTERFACE = 2, // ReferenceType is an interface
    ARRAY     = 3, // ReferenceType is an array
}

enum Tag: (int code)
{
    ARRAY        = 91,  // [ - array object (objectID size)
    BYTE         = 66,  // B - byte value (1 byte)
    CHAR         = 67,  // C - char (2 bytes)
    OBJECT       = 76,  // L - object (objectID size)
    FLOAT        = 70,  // F - float (4 byte)
    DOUBLE       = 68,  // D - double (8 bytes)
    INT          = 73,  // I - int (4 bytes)
    LONG         = 74,  // J - long (8 bytes)
    SHORT        = 83,  // S - short (2 bytes)
    VOID         = 86,  // V - void (0 bytes)
    BOOLEAN      = 90,  // Z - boolean (1 byte)
    STRING       = 115, // s - String (objectID size) 
    THREAD       = 116, // t - Threadd (objectID size)
    THREAD_GROUP = 103, // g - ThreadGroup (objectID size)
    CLASS_LOADER = 108, // l - ClassLoader (objectID size)
    CLASS_OBJECT = 99,  // c - class object (objectID size)
}

enum StepDepth: (int code)
{
    INTO = 0, // step into any method calls that occur before the end of the step
    OVER = 1, // step over any method calls that occur before the end of the step
    OUT  = 2, // step out of the current method
}

enum StepSize: (int code)
{
    MIN  = 0, // step by the minimum possible amount (often a bytecode instruction)
    LINE = 1, // step to the next source line unless there is no line number informatino in which case a MIN step is done instead
}

enum SuspendPolicy: (int code)
{
    NONE         = 0, // suspend no threads when this event is encountered
    EVENT_THREAD = 1, // suspend the event thread when this event is encountered
    ALL          = 2, // suspend all threads when this ecent is encountered
}

enum InvokeOptions: (int code)
{
    INVOKE_SINGLE_THREADED = 0x01,
    INVOKE_NONVIRTUAL      = 0x02,
}

enum ModifierType: (int code)
{
    COUNT                 = 1,
    CONDITIONAL           = 2,
    THREAD_ONLY           = 3,
    CLASS_ONLY            = 4,
    CLASS_MATCH           = 5,
    CLASS_EXCLUDE         = 6,
    LOCATION_ONLY         = 7,
    EXCEPTION_ONLY        = 8,
    FIELD_ONLY            = 9,
    STEP                  = 10,
    INSTANCE_ONLY         = 11,
    SOURCE_NAME_MATCH     = 12,
    PLATFORM_THREADS_ONLY = 13,
}

