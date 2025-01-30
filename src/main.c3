import std::io;
import jdwp;

// First start the debugger, through java or gradle
// JVM ARGS -agentlib:jdwp=transport=dt_socket,server=y,address=8000,suspend=n,quiet=y
// GRADLE ARGS --rerun-tasks test --debug-jvm

fn void main(String[] args)
{
    Jdwp jdwp = Jdwp.new();
    defer jdwp.close()!!;

    JClass[] classes = jdwp.vm_classes_by_signature("Ljava/lang/String;")!!;
    foreach(class: classes) {
        io::printfn("ref:%s", class.ref);
        io::printfn("type_id:%d", class.type_id);
        io::printfn("signature:%s", class.signature);
        io::printfn("status:%s\n", class.status);
    }
    // jdwp.vm_all_classes()!!;
    // jdwp.vm_create_string("robin")!!;
    // jdwp.vm_create_string("tordly")!!;

    // char[] encoded = encode_int(155);
    // foreach(c: encoded) io::printf("%02X ", c);
    // io::printn();
    // io::printfn("%d", decode_int(encoded));
}

