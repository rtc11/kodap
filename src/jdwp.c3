module jdwp;

import std::io;
import std::net;
import std::core::mem;

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

fn String! Jdwp.vm_version(&self)
{
    self.send({ 11, self.seq++, 0, 1, 1 })!;
    return self.read()!; 
}

fn String! Jdwp.vm_classes_by_signature(&self, String jni_signature = "Ljava/lang/Object;")
{
    // header size 11 + 4-byte length prefix for string + string length
    Command cmd = { 11 + 4 + jni_signature.len, self.seq++, 0, 1, 2 };
    self.send(cmd, encode_string(jni_signature))!;
    return self.read()!;
}

fn String! Jdwp.vm_all_classes(&self)
{
    Command cmd = { 11, self.seq++, 0, 1, 3 };
    self.send(cmd)!;
    return self.read()!;
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

fn void! Jdwp.send(&self, Command c, char[] data = {}) @private
{
    io::printfn("SEND id:%d flags:%d set:%d cmd:%d len:%d data:%s", c.id, c.flags, c.set, c.cmd, c.length, data);
    char[] packet = array::tconcat((char[11])c, data);
    if (self.socket.write(packet)!! != packet.len) return JdwpErr.SEND_COMMAND?;
}

fn String! Jdwp.read(&self) @private
{
    Reply reply;
    if (self.socket.read((char[11]*)&reply)!! != 11) return JdwpErr.READ_HEADER?;

    int data_len = reply.length - 11;
    io::printfn("READ id:%d flags:%d error:%d len:%d", reply.id, reply.flags, reply.error_code, data_len);

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
        char[] data = data_ptr[..data_len];
        if (self.socket.read(data)!! != data_len) return JdwpErr.READ_DATA?;
        String decoded = decode_string(data)!;
        io::printfn("%s", decoded);
        return decoded;
    }
    return "";
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
    int str_len = ((int)bytes[0] << 24) | ((int)bytes[1] << 16) | ((int)bytes[1] << 8) | ((int)bytes[3]);
    if (bytes.len < 4 + str_len) return JdwpErr.INVALID_DATA?;
    return (String) bytes[4..];
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

enum Commands: (int set, int cmd)
{
    VM_VERSION                                 = { 1, 1 },
    VM_CLASSES_BY_SIGNATURE                    = { 1, 2 },
    VM_ALL_CLASSES                             = { 1, 3 },
    VM_ALL_THREADS                             = { 1, 4 },
    VM_TOP_LVL_THREAD_GROUPS                   = { 1, 5 },
    VM_DISPOSE                                 = { 1, 6 },
    VM_ID_SIZES                                = { 1, 7 },
    VM_SUSPEND                                 = { 1, 8 },
    VM_RESUME                                  = { 1, 9 },
    VM_EXIT                                    = { 1, 10 },
    VM_CREATE_STRING                           = { 1, 11 },
    VM_CAPABILITIES                            = { 1, 12 },
    VM_CLASS_PATHS                             = { 1, 13 },
    VM_DISPOSE_OBJECTS                         = { 1, 14 },
    VM_HOLD_EVENTS                             = { 1, 15 },
    VM_RELEASE_EVENTS                          = { 1, 16 },
    VM_CAPABILITIES_NEW                        = { 1, 17 },
    VM_REDEFINE_CLASSES                        = { 1, 18 },
    VM_SET_DEFAULT_STRATUM                     = { 1, 19 },
    VM_ALL_CLASSES_WITH_GENERIC                = { 1, 20 },
    VM_INSTANCE_COUNTS                         = { 1, 21 },
    VM_ALL_MODULES                             = { 1, 22 },
    REF_TYPE_SIGNATURE                         = { 2, 1 },
    REF_TYPE_CLASS_LOADER                      = { 2, 2 },
    REF_TYPE_MODIFIES                          = { 2, 3 },
    REF_TYPE_FIELDS                            = { 2, 4 },
    REF_TYPE_METHODS                           = { 2, 5 },
    REF_TYPE_GET_VALUES                        = { 2, 6 },
    REF_TYPE_SOURCE_FILE                       = { 2, 7 },
    REF_TYPE_NESTED_TYPES                      = { 2, 8 },
    REF_TYPE_STATUS                            = { 2, 9 },
    REF_TYPE_INTERFACES                        = { 2, 10 },
    REF_TYPE_CLASS_OBJECT                      = { 2, 11 },
    REF_TYPE_SOURCE_DEBUG_EXTENSION            = { 2, 12 },
    REF_TYPE_SIGNATURE_WITH_GENERIC            = { 2, 13 },
    REF_TYPE_FIELDS_WITH_GENERIC               = { 2, 14 },
    REF_TYPE_METHODS_WITH_GENERIC              = { 2, 15 },
    REF_TYPE_INSTANCES                         = { 2, 16 },
    REF_TYPE_CLASS_FILE_VERSION                = { 2, 17 },
    REF_TYPE_CONSTANT_POOL                     = { 2, 18 },
    REF_TYPE_MODULE                            = { 2, 19 },
    CLASS_TYPE_SUPERCLASS                      = { 3, 1 },
    CLASS_TYPE_SET_VALUES                      = { 3, 2 },
    CLASS_TYPE_INVOKE_METHOD                   = { 3, 3 },
    CLASS_TYPE_NEW_INSTANCE                    = { 3, 4 },
    ARRAY_TYPE_NEW_INSTANCE                    = { 4, 1 },
    INTERFACE_TYPE_INVOKE_METHOD               = { 5, 1 },
    METHOD_LINE_TABLE                          = { 6, 1 },
    METHOD_VARIABLE_TABLE                      = { 6, 2 },
    METHOD_BYTECODES                           = { 6, 3 },
    METHOD_IS_OBSOLETE                         = { 6, 4 },
    METHOD_VARIABLE_TABLE_WITH_GENERIC         = { 6, 5 },
    OBJ_REF_REFERENCE_TYPE                     = { 9, 1 },
    OBJ_REF_GET_VALUES                         = { 9, 2 },
    OBJ_REF_SET_VALUES                         = { 9, 3 },
    OBJ_REF_MONITOR_INFO                       = { 9, 5 },
    OBJ_REF_INVOKE_METHOD                      = { 9, 6 },
    OBJ_REF_DISABLE_COLLECTION                 = { 9, 7 },
    OBJ_REF_ENABLE_COLLECTION                  = { 9, 8 },
    OBJ_REF_IS_COLLECTED                       = { 9, 9 },
    OBJ_REF_REFERRING_OBJECTS                  = { 9, 10 },
    STRING_REF_VALUE                           = { 10, 1 },
    THREAD_REF_NAME                            = { 11, 1 },
    THREAD_REF_SUSPEND                         = { 11, 2 },
    THREAD_REF_RESUME                          = { 11, 3 },
    THREAD_REF_STATUS                          = { 11, 4 },
    THREAD_REF_THREAD_GROUP                    = { 11, 5 },
    THREAD_REF_FRAMES                          = { 11, 6 },
    THREAD_REF_FRAME_COUNT                     = { 11, 7 },
    THREAD_REF_OWNED_MONITORS                  = { 11, 8 },
    THREAD_REF_CURRENT_CONTENDED_MONITOR       = { 11, 9 },
    THREAD_REF_STOP                            = { 11, 10 },
    THREAD_REF_INTERRUPT                       = { 11, 11 },
    THREAD_REF_SUSPEND_COUNT                   = { 11, 12 },
    THREAD_REF_OWNED_MONITORS_STACK_DEPTH_INFO = { 11, 13 },
    THREAD_REF_FORCE_EARLY_RETURN              = { 11, 14 },
    THREAD_REF_IS_VIRTUAL                      = { 11, 15 },
    THREAD_GROUP_REF_NAME                      = { 12, 1 },
    THREAD_GROUP_REF_PARENT                    = { 12, 2 },
    THREAD_GROUP_REF_CHILDREN                  = { 12, 3 },
    ARRAY_REF_LENGHT                           = { 13, 1 },
    ARRAY_REF_GET_VALUES                       = { 13, 2 },
    ARRAY_REF_SET_VALUES                       = { 13, 3 },
    CLASS_LOADER_REF_VISIBLE_CLASSES           = { 14, 1 },
    EVENT_REQUEST_SET                          = { 15, 1 },
    EVENT_REQUEST_CLEAR                        = { 15, 2 },
    EVENT_REQUEST_CLEAR_ALL_BREAKPOINTS        = { 15, 3 },
    STACK_FRAME_GET_VALUES                     = { 16, 1 },
    STACK_FRAME_SET_VALUES                     = { 16, 2 },
    STACK_FRAME_THIS_OBJECT                    = { 16, 3 },
    STACK_FRAME_POP_FRAMES                     = { 16, 4 },
    CLASS_OBJECT_REF_REFLECTED_TYPE            = { 17, 1 },
    MODULE_REF_NAME                            = { 18, 1 },
    MODULE_REF_CLASS_LOADER                    = { 18, 2 },
    EVENT_COMPOSITE                            = { 64, 100 },
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
