module jdwp;

import std::io;
import std::net;
import std::core::mem;

distinct Byte = char[1];
distinct Boolean = char[1];
distinct Int = char[4];
distinct Long = char[8];
distinct ObjectID = char[11];
distinct ThreadId = char[11];

struct Jdwp
{
    TcpSocket socket;
    int seq;
}

bitstruct Command : char[11] @bigendian 
{
    uint length: 0..31;
    uint id:     32..63;
    uint flags:  64..71;
    uint set:    72..79;
    uint cmd:    80..87;
}

bitstruct Reply: char[11] @bigendian 
{
    uint length:     0..31;
    uint id:         32..63;
    uint flags:      64..71;
    uint error_code: 72..87;
}

fn Jdwp Jdwp.new() @operator(construct)
{
    Jdwp jdwp;
    jdwp.connect()!!;
    return jdwp;
}

fn void! Jdwp.connect(&self, String host = "127.0.0.1", uint port = 5005)
{
    self.socket = tcp::connect(host, port)!;
    self.seq = 1;
    self.handshake()!;
}

fn void! Jdwp.close(&self) => self.socket.close()!;

struct VersionReply
{
    String description;
    int jdwp_major;
    int jdwp_minor;
    String vm_version;
    String vm_name;
}

fn VersionReply! Jdwp.vm_version(&self) 
{
    self.send({ 11, self.seq++, 0, 1, 1 })!;
    char[] data = self.read()!;

    VersionReply reply;
    int offset = 0;

    reply.description = decode_string(data)!;
    offset += 4 + reply.description.len;

    reply.jdwp_major = decode_int(data[offset..])!;
    offset += 4;

    reply.jdwp_minor = decode_int(data[offset..])!;
    offset += 4;

    reply.vm_version = decode_string(data[offset..])!;
    offset += 4 + reply.vm_version.len;

    reply.vm_name = decode_string(data[offset..])!;

    return reply;
} 

fn String! Jdwp.vm_classes_by_signature(&self, String jni_signature = "Ljava/lang/Object;")
{
    // header size 11 + 4-byte length prefix for string + string length
    Command cmd = { 11 + 4 + jni_signature.len, self.seq++, 0, 1, 2 };
    return self.exchange(cmd, encode_string(jni_signature))!;
}

fn String! Jdwp.vm_all_classes(&self) => self.exchange({ 11, self.seq++, 0, 1, 3 })!;
fn String! Jdwp.vm_all_threads(&self) => self.exchange({ 11, self.seq++, 0, 1, 4 })!;
fn String! Jdwp.vm_top_level_thread_groups(&self) => self.exchange({ 11, self.seq++, 0, 1, 5 })!;
fn String! Jdwp.vm_dispose(&self) => self.exchange({ 11, self.seq++, 0, 1, 6 })!;
fn String! Jdwp.vm_id_sizes(&self) => self.exchange({ 11, self.seq++, 0, 1, 7 })!;
fn String! Jdwp.vm_suspend(&self) => self.exchange({ 11, self.seq++, 0, 1, 8 })!;
fn String! Jdwp.vm_resume(&self) => self.exchange({ 11, self.seq++, 0, 1, 9 })!;
fn void! Jdwp.vm_exit(&self) => self.send({ 11, self.seq++, 0, 1, 10 })!;
fn String! Jdwp.vm_create_string(&self, String str)
{
    // header size 11 + 4-byte length prefix for string + string length
    Command cmd = { 11 + 4 + str.len, self.seq++, 0, 1, 11 };
    return self.exchange(cmd, encode_string(str))!;
}


fn void! Jdwp.handshake(&self) @private
{
    char[14] res;
    char[14] handshake = "JDWP-Handshake";
    if (self.socket.write(&handshake)!! != 14) return JdwpErr.SEND_HANDSHAKE?;
    if (self.socket.read(&res)!! != 14) return JdwpErr.RECV_HANDSHAKE?;
    if (res != handshake) return JdwpErr.DIFF_HANDSHAKE?;
    // read past some unknown handshake reply
    char[18] res2;
    self.socket.read(&res2)!;
    self.socket.read(&res2)!;
}

fn String! Jdwp.exchange(&self, Command c, char[] data = {})
{
    self.send(c, data)!;
    return self.read_string()!;
}

fn void! Jdwp.send(&self, Command c, char[] data = {}) @private
{
    io::printfn("SEND id:%d flags:%3d set:%3d cmd:%d len:%d data:%s", c.id, c.flags, c.set, c.cmd, c.length, data);
    char[] packet = array::tconcat((char[11])c, data);
    if (self.socket.write(packet)!! != packet.len) return JdwpErr.SEND_COMMAND?;
}

fn char[]! Jdwp.read(&self) @private
{
    Reply reply;
    if (self.socket.read((char[11]*)&reply)!! != 11) return JdwpErr.READ_HEADER?;

    int data_len = reply.length - 11;
    io::printfn("READ id:%d flags:%3d error:%d len:%d", reply.id, reply.flags, reply.error_code, data_len);

    if (reply.error_code != 0) {
        foreach(err: ErrorCode.values) {
            if (err.code == reply.error_code) {
                io::printfn("ERROR %d (%s) %s", err.code, err, err.desc);
            }
        }
    }

    if (data_len > 0) {
        char* data_ptr = mem::malloc(data_len);
        // defer mem::free(data_ptr); // when or how to free?
        char[] data = data_ptr[..data_len - 1];
        if (self.socket.read(data)!! != data_len) return JdwpErr.READ_DATA?;
        // foreach(ch: data) io::printf("%02X ", ch);
        // io::printn();
        return data;
    }
    return {};
}
fn String! Jdwp.read_string(&self) @private
{
    Reply reply;
    if (self.socket.read((char[11]*)&reply)!! != 11) return JdwpErr.READ_HEADER?;

    int data_len = reply.length - 11;
    io::printfn("READ id:%d flags:%3d error:%d len:%d", reply.id, reply.flags, reply.error_code, data_len);

    if (reply.error_code != 0) {
        foreach(err: ErrorCode.values) {
            if (err.code == reply.error_code) {
                io::printfn("ERROR %d (%s) %s", err.code, err, err.desc);
            }
        }
    }

    if (data_len > 0) {
        char* data_ptr = mem::malloc(data_len);
        defer mem::free(data_ptr);
        char[] data = data_ptr[..data_len - 1];
        if (self.socket.read(data)!! != data_len) return JdwpErr.READ_DATA?;
        String decoded = decode_string(data)!;
        io::printfn("%s", decoded);
        foreach(ch: data) {
            io::printf("%x", ch);
        }
        io::printn();
        return decoded;
    }
    return "";
}

fn int! decode_int(char[] data) {
    if (data.len < 4) return JdwpErr.INVALID_DATA?;
    return ((int)(uint)data[0] << 24) |
           ((int)(uint)data[1] << 16) | 
           ((int)(uint)data[2] << 8)  |
           ((int)(uint)data[3]);
}

fn char[] encode_string(String str) @private
{
    int str_len = str.len;
    char[4] length_prefix;
    length_prefix[0] = (char)(str_len >> 24) & 0xFF;
    length_prefix[1] = (char)(str_len >> 16) & 0xFF;
    length_prefix[2] = (char)(str_len >> 8)  & 0xFF;
    length_prefix[3] = (char)(str_len)       & 0xFF;
    return array::tconcat(length_prefix, (char[]) str);
}

fn String! decode_string(char[] bytes) @private
{
    if (bytes.len < 4) return JdwpErr.INVALID_DATA?;
    int str_len = decode_int(bytes)!;

    if (str_len + 4 <= bytes.len) {
        return (String) bytes[4 .. (str_len + 4 - 1)];
    }
    io::printfn("str_len is %d but the buffer is only %d", str_len, bytes.len);
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
}

enum ErrorCode: (int code, String desc)
{
    NONE                                    = { 0, "no error has occured" },
    INVALID_THREAD                          = { 10, "the thread is null or not a valid thread" },
    INVALID_THREAD_GROUP                    = { 11, "thread group invalid" },
    INVALID_PRIORITY                        = { 12, "invalid priority" },
    THREAD_NOT_SUSPENDED                    = { 13, "if the specified thread has not been suspended by an event" },
    THREAD_SUSPENDED                        = { 14, "thread already suspended" },
    THREAD_NOT_ALIVE                        = { 15, "not used" },
    INVALID_OBJECT                          = { 20, "if this reference type has been unloaded and garbage collected" },
    INVALID_CLASS                           = { 21, "invalid class" },
    CLASS_NOT_PREPARED                      = { 22, "class has been loaded but not yet prepared" },
    INVALID_METHODID                        = { 23, "invalid method" },
    INVALID_LOCATION                        = { 24, "invalid location" },
    INVALID_FIELDID                         = { 25, "invalid field" },
    INVALID_FRAMEID                         = { 30, "invalid jframeID" },
    NO_MORE_FRAMES                          = { 31, "there are no more Java or JNI frames on the call stack" },
    OPAQUE_FRAME                            = { 32, "info about the frame it unavailable (e.g native frame)" },
    NOT_CURRENT_FRAME                       = { 33, "operation can only be performed on current frame" }, 
    TYPE_MISMATCH                           = { 34, "the variable is not an appropriate type for the function used" },
    INVALID_SLOT                            = { 35, "invalid slot" },
    DUPLICATE                               = { 40, "item already set" },
    NOT_FOUND                               = { 41, "desired element not found" },
    INVALID_MODULE                          = { 42, "invalid module" },
    INVALID_MONITOR                         = { 50, "invalid monitor" },
    NOT_MONITOR_OWNER                       = { 51, "the thread doesnt own the monitor" },
    INTERRUPT                               = { 52, "the call has been interrupted before completion" },
    INVALID_CLASS_FORMAT                    = { 60, "the VM attempted to read a class file and determined that the file is malformed or cannot be interpreded as class file" },
    CIRCULAR_CLASS_DEFINITION               = { 61, "a circularity has been detected while initializing a class" },
    FAILS_VERIFICATION                      = { 62, "the verifier detected that a class file contained som internal inconsitency or security problem" },
    ADD_METHOD_NOT_IMPLEMENTED              = { 63, "adding methods has not been implemneted" },
    SCHEMA_CHANGE_NOT_IMPLEMENTED           = { 64, "schema change has not been implemented" },
    INVALID_TYPESTATE                       = { 65, "the state of the thread has been modified, and is now incosistent" },
    HIERARCHY_CHANGE_NOT_IMPLEMENTED        = { 66, "a direct superclass is different for the new class version or.." },
    DELETE_METHOD_NOT_IMPLEMENTED           = { 67, "the new class version does not declare a method declared in the old class version" },
    UNSUPPORTED_VERSION                     = { 68, "a class file has a version number not supported by this VM" },
    NAMES_DONT_MATCH                        = { 69, "the class name defined in the new class file is different from the name in the old class object" },
    CLASS_MODIFIERS_CHANGE_NOT_IMPLEMENTED  = { 70, "the new class versino has different modifiers and canUnrestrictedlyRedefineClasses is false" },
    METHOD_MODIFIERS_CHANGE_NOT_IMPLEMENTED = { 71, "a method in the new class versino has different modifiers" },
    CLASS_ATTRIBUTE_CHANGE_NOT_IMPLEMENTED  = { 72, "the new class versino has a different NestHost, nestMembers, PermittedSubclasses or Record class attribute" },
    NOT_IMPLEMENTED                         = { 99, "the functionality is not implemented in this VM" },
    NULL_POINTER                            = { 100, "invalid pointer" },
    ABSENT_INFORMATION                      = { 101, "desired informatino is not available" }, 
    INVALID_EVENT_TYPE                      = { 102, "the specified event type id is not recognized" },
    ILLEGAL_ARGUMENT                        = { 103, "illegal argument" },
    OUT_OF_MEMORY                           = { 110, "the function needed to allocate memory and no more memory was available for allocation" },
    ACCESS_DENIED                           = { 111, "debugging has not been enabled in this VM. JVMTI cannot be used" },
    VM_DEAD                                 = { 112, "the VM is not running" },
    INTERNAL                                = { 113, "an unexpected internal error has occured" },
    UNATTACHED_THREAD                       = { 115, "the thread being used to call this function is not attached to the vm." }, 
    INVALID_TAG                             = { 500, "object type id or class tag" },
    ALREADY_INVOKING                        = { 502, "previous invoke not complete" },
    INVALID_INDEX                           = { 503, "index is invalid" },
    INVALID_LENGTH                          = { 504, "the length is invalid" },
    INVALID_STRING                          = { 506, "the string is invalid" },
    INVALID_CLASS_LOADER                    = { 507, "the class loader is invalid" },
    INVALID_ARRAY                           = { 508, "the array is invalid" },
    TRANSPORT_LOAD                          = { 509, "unable to load the transport" },
    TRANSPORT_INIT                          = { 510, "unable to initialize the transport" },
    NATIVE_METHOD                           = { 511, "" },
    INVALID_COUNT                           = { 512, "the count is invalid" },
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

enum Tag: (int cod)
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

// https://docs.oracle.com/en/java/javase/21/docs/specs/jdwp/jdwp-spec.html
