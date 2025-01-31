import std::io;
import jdwp;

// First start the debugger, through java or gradle
// JVM ARGS -agentlib:jdwp=transport=dt_socket,server=y,address=8000,suspend=n,quiet=y
// GRADLE ARGS --rerun-tasks test --debug-jvm

fn void main(String[] args)
{
    // example_method();
    example_classes_by_signature();
    // example_version(jdwp);

    // jdwp.vm_all_classes()!!;
    // jdwp.vm_create_string("robin")!!;
    // jdwp.vm_create_string("tordly")!!;

    // char[] encoded = encode_int(155);
    // foreach(c: encoded) io::printf("%02X ", c);
    // io::printn();
    // io::printfn("%d", decode_int(encoded));
}

fn void example_version()
{
    Jdwp jdwp = Jdwp.new();
    defer jdwp.close()!!;

    Version v = jdwp.vm_version()!!;
    io::printfn("description: %s", v.description);
    io::printfn("jdwp.major:  %d", v.jdwp_major);
    io::printfn("jdwp.minor:  %d", v.jdwp_minor);
    io::printfn("vm.version:  %s", v.vm_version);
    io::printfn("vm.name:     %s", v.vm_name);
}

fn void example_method()
{
    Jdwp jdwp = Jdwp.new();
    defer jdwp.close()!!;

    Class[] classes = jdwp.vm_classes_by_signature("Lapp/MainTest;")!!;
    foreach(class: classes) {
        io::printfn("ref:%s", class.ref);
        io::printfn("type_id:%s", class.id);
        io::printfn("signature:%s", class.signature);
        io::printfn("status:%s\n", class.status);
    }
}

fn void example_classes_by_signature()
{
    Jdwp jdwp = Jdwp.new();
    defer jdwp.close()!!;

    Class[] classes = jdwp.vm_classes_by_signature("Ljava/lang/String;")!!;
    foreach(class: classes) {
        io::printfn("ref:%s", class.ref);
        io::printfn("type_id:%s", class.id);
        io::printfn("signature:%s", class.signature);
        io::printfn("status:%s\n", class.status);
    }
}
