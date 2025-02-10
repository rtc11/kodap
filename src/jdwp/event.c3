module jdwp::event;

import jdwp;
import std::io;
import std::collections::anylist;


fn any set(Reply *reply)
{
    char[] data = reply.body[:reply.length];
    int offset = 0;
    int request_id = jdwp::decode_int(data, &offset)!!;
    return @clone(request_id);
}

fn void Jdwp.set(&self, int id, RequestSet set, RequestSetModifier* mod)
{
    if(mod) {
        char[] mod_ch = mod.to_char();
        Command cmd = { 11 + $sizeof(set) + mod_ch.len, id, 0, 15, 1 };
        char[] set_mods = array::tconcat((char[6])set, mod_ch);
        self.send(cmd, set_mods)!!;
    } else {
        Command cmd = { 11 + $sizeof(set), id, 0, 15, 1 };
        self.send(cmd, (char[6]*) &set)!!;
    }
}

struct Event 
{
    bitstruct : char[11] @bigendian 
    {
        uint length: 0..31;
        uint id:     32..63;
        char flags:  64..71;
        char set:    72..79;
        char cmd:    80..87;
    }
    char[?] data;
}

struct EventData
{
    SuspendPolicy suspend_policy;
    EventKind kind; // necessary?
    AnyList events;
}

// [0, 0, 0, 29, 0, 0, 0, 1, 0, 64, 100, 0, 0, 0, 0, 1, 6, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 2, 
//  0, 0, 0, 29, 0, 0, 0, 2, 0, 64, 100, 0, 0, 0, 0, 1, 6, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 1]
//  ^len         ^id         ^f ^   ^    ^sp^events     ^kind
                
fn any from(Event *event) 
{
    char[] buf = event.data[:event.length];
    int offset = 0;
    EventData event_data;
    switch (jdwp::decode_char(buf, &offset)!!) {
        case '0': event_data.suspend_policy = NONE;
        case '1': event_data.suspend_policy = EVENT_THREAD;
        case '2': event_data.suspend_policy = ALL;
    }
    int size = jdwp::decode_int(buf, &offset)!!;
    if (size == 0) return event;
    AnyList events;
    events.new_init(size);
    for(int i=0; i<size; i++) {
        switch ((int) jdwp::decode_char(buf, &offset)!! - '0') {
            case 1:   events.push(single_step(buf, &offset));
            case 2:   events.push(breakpoint(buf, &offset));
            // case 3:   events.push(frame_pop(buf, &offset));
            case 4:   events.push(exception(buf, &offset));
            // case 5:   events.push(user_defined(buf, &offset));
            case 6:   events.push(thread_start(buf, &offset));
            case 7:   events.push(thread_death(buf, &offset));
            case 8:   events.push(class_prepare(buf, &offset));
            case 9:   events.push(class_unload(buf, &offset));
            // case 10:  events.push(class_load(buf, &offset));
            case 20:  events.push(field_access(buf, &offset));
            case 21:  events.push(field_modification(buf, &offset));
            case 30:  events.push(exception(buf, &offset)); // ????
            case 40:  events.push(method_entry(buf, &offset));
            case 41:  events.push(method_exit(buf, &offset));
            case 42:  events.push(method_exit_val(buf, &offset));
            case 43:  events.push(monitor_contended_enter(buf, &offset));
            case 44:  events.push(monitor_contended_entered(buf, &offset));
            case 45:  events.push(monitor_wait(buf, &offset));
            case 46:  events.push(monitor_waited(buf, &offset));
            case 90:  events.push(vm_start(buf, &offset));
            case 99:  events.push(vm_death(buf, &offset));
            // case 100: events.push(vm_disconnected(buf, &offset));
            default: io::printfn("ERROR EventKind");
        }
    }
    return event;
}

fn SingleStep single_step(char[] buf, int* offset) =>
{
    .request_id = jdwp::decode_int(buf, offset)!!,
    .thread = jdwp::decode_id(buf, offset)!!,
};

fn Breakpoint breakpoint(char[] buf, int* offset) =>
{
    .request_id = jdwp::decode_int(buf, offset)!!,
    .thread = jdwp::decode_id(buf, offset)!!,
    .location = location(buf, offset),
};

fn Location location(char[] buf, int* offset)
{
    char[17] location;
    for (int i = 0; i < location.len; i++) {
        location[i] = buf[*offset +i]; 
    }
    offset += location.len;
    return (Location) location;
}

fn TypeTag! type_tag(char[] buf, int* offset)
{
    switch (jdwp::decode_char(buf, offset)!!) {
        case '1': return TypeTag.CLASS;
        case '2': return TypeTag.INTERFACE;
        case '3': return TypeTag.ARRAY;
        default: return JdwpErr.INVALID_DATA?;
    }
}

fn Value! value(char[] buf, int* offset)
{
    switch ((int) jdwp::decode_char(buf, offset)!! - '0') {
        case 66: return { .tag = BYTE, .byte = jdwp::decode_char(buf, offset)!! };
        case 67: return { .tag = CHAR, .byte = jdwp::decode_char(buf, offset)!! };
        case 68: return { .tag = DOUBLE, .byte = jdwp::decode_char(buf, offset)!! };
        case 70: return { .tag = FLOAT, .byte = jdwp::decode_char(buf, offset)!! };
        case 73: return { .tag = INT, .byte = jdwp::decode_char(buf, offset)!! };
        case 74: return { .tag = LONG, .byte = jdwp::decode_char(buf, offset)!! };
        case 76: return { .tag = OBJECT, .byte = jdwp::decode_char(buf, offset)!! };
        case 83: return { .tag = SHORT, .byte = jdwp::decode_char(buf, offset)!! };
        case 86: return { .tag = VOID, .byte = jdwp::decode_char(buf, offset)!! };
        case 90: return { .tag = BOOLEAN, .byte = jdwp::decode_char(buf, offset)!! };
        case 91: return { .tag = ARRAY, .byte = jdwp::decode_char(buf, offset)!! };
        case 115: return { .tag = STRING, .byte = jdwp::decode_char(buf, offset)!! };
        case 116: return { .tag = THREAD, .byte = jdwp::decode_char(buf, offset)!! };
        case 103: return { .tag = THREAD_GROUP, .byte = jdwp::decode_char(buf, offset)!! };
        case 108: return { .tag = CLASS_LOADER, .byte = jdwp::decode_char(buf, offset)!! };
        case 99: return { .tag = CLASS_OBJECT, .byte = jdwp::decode_char(buf, offset)!! };
        default: return JdwpErr.INVALID_DATA?;
    }
}
fn ThreadStart thread_start(char[] buf, int* offset) =>
{
    .request_id = jdwp::decode_int(buf, offset)!!,
    .thread = jdwp::decode_id(buf, offset)!!,
};
fn ThreadDeath thread_death(char[] buf, int* offset) =>
{
    .request_id = jdwp::decode_int(buf, offset)!!,
    .thread = jdwp::decode_id(buf, offset)!!,
};
fn ClassPrepare class_prepare(char[] buf, int* offset) =>
{
    .request_id = jdwp::decode_int(buf, offset)!!,
    .thread = jdwp::decode_id(buf, offset)!!,
    .ref_type_tag = type_tag(buf, offset)!!,
    .type_id = jdwp::decode_id(buf, offset)!!,
    .status = jdwp::decode_int(buf, offset)!!,
};
fn ClassUnload class_unload(char[] buf, int* offset) =>
{
    .request_id = jdwp::decode_int(buf, offset)!!,
    .signature = jdwp::decode_string(buf, offset)!!,
};
fn FieldAccess field_access(char[] buf, int* offset) =>
{
    .request_id = jdwp::decode_int(buf, offset)!!,
    .thread = jdwp::decode_id(buf, offset)!!,
    .location = location(buf, offset),
    .ref_type_tag = type_tag(buf, offset)!!,
    .type_id = jdwp::decode_id(buf, offset)!!,
    .field_id = jdwp::decode_id(buf, offset)!!,
    .object = jdwp::decode_id(buf, offset)!!,
};
fn FieldModification field_modification(char[] buf, int* offset) =>
{
    .request_id = jdwp::decode_int(buf, offset)!!,
    .thread = jdwp::decode_id(buf, offset)!!,
    .location = location(buf, offset),
    .ref_type_tag = type_tag(buf, offset)!!,
    .type_id = jdwp::decode_id(buf, offset)!!,
    .field_id = jdwp::decode_id(buf, offset)!!,
    .value_to_be = value(buf, offset)!!,
};
fn Exception exception(char[] buf, int* offset) =>
{
    .request_id = jdwp::decode_int(buf, offset)!!,
    .thread = jdwp::decode_id(buf, offset)!!,
    .location = location(buf, offset),
    .exception = jdwp::decode_id(buf, offset)!!,
    .catch_location = location(buf, offset),
};
fn MethodEntry method_entry(char[] buf, int* offset) =>
{
    .request_id = jdwp::decode_int(buf, offset)!!,
    .thread = jdwp::decode_id(buf, offset)!!,
    .location = location(buf, offset),
};
fn MethodExit method_exit(char[] buf, int* offset) =>
{
    .request_id = jdwp::decode_int(buf, offset)!!,
    .thread = jdwp::decode_id(buf, offset)!!,
    .location = location(buf, offset),
};
fn MethodExitVal method_exit_val(char[] buf, int* offset) =>
{
    .request_id = jdwp::decode_int(buf, offset)!!,
    .thread = jdwp::decode_id(buf, offset)!!,
    .location = location(buf, offset),
    .value = value(buf, offset)!!,
};
fn MonitorCenteredEnter monitor_contended_enter(char[] buf, int* offset) =>
{
    .request_id = jdwp::decode_int(buf, offset)!!,
    .thread = jdwp::decode_id(buf, offset)!!,
    .object = jdwp::decode_id(buf, offset)!!,
    .location = location(buf, offset),
};
fn MonitorCenteredEntered monitor_contended_entered(char[] buf, int* offset) =>
{
    .request_id = jdwp::decode_int(buf, offset)!!,
    .thread = jdwp::decode_id(buf, offset)!!,
    .object = jdwp::decode_id(buf, offset)!!,
    .location = location(buf, offset),
};
fn MonitorWait monitor_wait(char[] buf, int* offset) =>
{
    .request_id = jdwp::decode_int(buf, offset)!!,
    .thread = jdwp::decode_id(buf, offset)!!,
    .object = jdwp::decode_id(buf, offset)!!,
    .location = location(buf, offset),
    .timeout = jdwp::decode_long(buf, offset)!!,
};
fn MonitorWaited monitor_waited(char[] buf, int* offset) =>
{
    .request_id = jdwp::decode_int(buf, offset)!!,
    .thread = jdwp::decode_id(buf, offset)!!,
    .object = jdwp::decode_id(buf, offset)!!,
    .location = location(buf, offset),
    .timed_out = (bool) jdwp::decode_int(buf, offset)!!,
};
fn VmStart vm_start(char[] buf, int* offset) =>
{
    .request_id = jdwp::decode_int(buf, offset)!!,
    .thread = jdwp::decode_id(buf, offset)!!,
};
fn VmDeath vm_death(char[] buf, int* offset) => { jdwp::decode_int(buf, offset)!! };

struct VmStart
{
    // VM_START
    int request_id;
    Id thread;
}
struct SingleStep
{
    // SINGLE_STEP
    int request_id;
    Id thread;
    Location location;
}

struct Breakpoint
{
    // BREAKPOINT
    int request_id;
    Id thread;
    Location location;
}

struct MethodEntry
{
    // METHOD_ENTRY
    int request_id;
    Id thread;
    Location location;
}

struct MethodExit
{
    // METHOD_EXIT
    int request_id;
    Id thread;
    Location location;
}
struct MethodExitVal
{
    // METHOD_EXIT_WITH_RETURN_VALUE
    int request_id;
    Id thread;
    Location location;
    Value value;
}
struct MonitorCenteredEnter
{
    // MONITOR_CONTENDED_ENTER
    int request_id;
    Id thread;
    Id object;
    Location location;
}
struct MonitorCenteredEntered
{
    // MONITOR_CONTENDED_ENTERED
    int request_id;
    Id thread;
    Id object;
    Location location;
}
struct MonitorWait
{
    // MONITOR_WAIT
    int request_id;
    Id thread;
    Id object;
    Location location;
    long timeout;
}
struct MonitorWaited
{
    // MONITOR_WAITED
    int request_id;
    Id thread;
    Id object;
    Location location;
    bool timed_out;
}
struct Exception
{
    // EXCEPTION
    int request_id;
    Id thread;
    Location location;
    Id exception; // tagged-objectID
    Location catch_location;
}
struct ThreadStart
{
    // THREAD_START
    int request_id;
    Id thread;
}
struct ThreadDeath
{
    // THREAD_DEATH
    int request_id;
    Id thread;
}
struct ClassPrepare
{
    // CLASS_PREPARE
    int request_id;
    Id thread;
    TypeTag ref_type_tag; 
    Id type_id;
    int status;
}
struct ClassUnload
{
    // CLASS_UNLOAD
    int request_id;
    String signature;
}
struct FieldAccess
{
    // FIELD_ACCESS
    int request_id;
    Id thread;
    Location location;
    TypeTag ref_type_tag;
    Id type_id;
    Id field_id;
    Id object;
}
struct FieldModification
{
    // FIELD_MODIFICATION
    int request_id;
    Id thread;
    Location location;
    TypeTag ref_type_tag;
    Id type_id;
    Id field_id;
    Value value_to_be;
}
struct VmDeath
{
    // VM_DEATH
    int request_id;
}
// }


struct Value
{
    Tag tag;
    union {
        char    byte;          // B - byte value (1 byte)
        char[2] jchar;         // C - char (2 bytes) // short
        char[8] jdouble;       // D - double (8 bytes)
        char[4] jfloat;        // F - float (4 byte)
        char[4] jint;          // I - int (4 bytes)
        char[8] jlong;         // J - long (8 bytes)
        char[8] jobject;       // L - object (objectID size)
        char[2] jshort;        // S - short (2 bytes)
                               // V - void (0 bytes)
        char[1] jboolean;      // Z - boolean (1 byte)
        char[8] jarray_object; // [ - array object (objectID size)
        char[8] jstring;       // s - String (objectID size)
        char[8] jthread;       // t - Threadd (objectID size)
        char[8] jthread_group; // g - ThreadGroup (objectID size)
        char[8] jclass_loader; // l - ClassLoader (objectID size)
        char[8] jclass_object; // c - class object (objectID size)
    }
}

bitstruct Location: char[17] @bigendian
{
    char type_tag: 0..7;
    long class_id: 8..71;
    ulong index: 72..135;
}

bitstruct RequestSet: char[6] @bigendian
{
    char event_kind:      0..7;   // EventKind
    char suspend_policy:  8..15;  // SuspendPolicy
    uint  modifiers_count: 16..47;
}

struct RequestSetModifier
{
    bitstruct : char[17] @overlap // @bigendian
    {
        char kind:              0..7; // ModifierType

        uint count:             8..39;
        uint expr_id:           8..39;
        long clazz:             8..71;
        long exception_or_null: 8..71;
        char caught:            8..15;
        char uncaught:          8..15;

        long declaring:         8..71;
        long field_id:          72..135;

        long thread:            8..71;
        int size:               72..103;
        int depth:              104..135;

        long instance:          8..71;
    }

    char[] string; // kind 5, 6, 12
}

fn char[] RequestSetModifier.to_char(&self)
{
    switch (self.kind) {
        case ModifierType.COUNT.code:
            char[] bits = (char[5]*) self;
            return bits;
        case ModifierType.CLASS_MATCH.code: 
        case ModifierType.LOCATION_ONLY.code:
            char[] bits = (char[1]*) self;
            char[] str = jdwp::encode_string((String) self.string);
            return array::tconcat(bits, str); 
    }

    return {};
}

