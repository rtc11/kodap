import std::io;
import jdwp;
import std::thread;
import std::net;

// First start the debugger, through java or gradle
// JVM ARGS -agentlib:jdwp=transport=dt_socket,server=y,address=8000,suspend=n,quiet=y
// GRADLE ARGS --rerun-tasks test --debug-jvm

fn void main(String[] args)
{

    example_poll();

    // example_set(EventKind.CLASS_PREPARE);
    // example_method();
    // example_all_classes();
    // example_classes_by_signature();
    // example_version();
}

fn void example_poll()
{
    Jdwp jdwp = Jdwp.new();
    defer jdwp.close();

    Thread t;
    t.create((ThreadFn) &Jdwp.start_event_loop, &jdwp)!!;

    while RUNNING: (true) {
        String input = io::readline()!!.trim();
        switch (input) {
            case "version": jdwp.send({ 11, jdwp.seq+=1, 0, 1, 1 })!!;
            case "quit": 
            case "exit": break RUNNING;
            default: io::printfn("%s not implemented", input);
        }
    }

    t.join()!!;
    jdwp.stop_event_loop();
    jdwp.vm_exit();
}

fn void example_version()
{
    Jdwp jdwp = Jdwp.new();
    defer jdwp.close();

    // Version v = jdwp.vm_version();
    jdwp.vm_version();
    // io::printfn("description: %s", v.description);
    // io::printfn("jdwp.major:  %d", v.jdwp_major);
    // io::printfn("jdwp.minor:  %d", v.jdwp_minor);
    // io::printfn("vm.version:  %s", v.vm_version);
    // io::printfn("vm.name:     %s", v.vm_name);
}

fn void example_set(EventKind event)
{
    Jdwp jdwp = Jdwp.new();
    defer jdwp.close();

    RequestSet set = {
        .event_kind = (char) event.code,
        .suspend_policy = (char) SuspendPolicy.NONE.code,
        .modifiers_count = 1,
    };

    RequestSetModifier mod = {
        .kind = ModifierType.COUNT.code,
        .count = 1,
    };

    // Modifier mod = {
    //     .kind = ModifierType.CLASS_MATCH.code,
    //     .string = "*.Hello",
    // };

    jdwp.set(set, mod);
    // io::printfn("%s", ref);
    // while WAIT: (true) {
    //     char[] data = jdwp.read_string()!!;
    //     if (data.len > 0) break WAIT;
    // }
}

fn void example_all_classes()
{
    Jdwp jdwp = Jdwp.new();
    defer jdwp.close();

    jdwp.vm_all_classes();
    // Class[] classes = jdwp.vm_all_classes();
    // foreach(class: classes) {
        // io::printfn("ref:%s", class.ref);
        // io::printfn("type_id:%s", class.id);
        // io::printfn("signature:%s", class.signature);
        // io::printfn("status:%s\n", class.status);
    // }
}

// fn void example_method()
// {
//     Jdwp jdwp = Jdwp.new();
//     defer jdwp.close()!!;
//
//     Class[] classes = jdwp.vm_classes_by_signature("Lapp/MainTest;")!!;
//     foreach(class: classes) {
//         io::printfn("ref:%s", class.ref);
//         io::printfn("type_id:%s", class.id);
//         io::printfn("signature:%s", class.signature);
//         io::printfn("status:%s\n", class.status);
//     }
// }

fn void example_classes_by_signature()
{
    Jdwp jdwp = Jdwp.new();
    defer jdwp.close();

    // Class[] classes = jdwp.vm_classes_by_signature("Ljava/lang/String;")!!;
    jdwp.vm_classes_by_signature("Lhello/Main;");
    // Class[] classes = jdwp::vm_classes_by_signature("Lhello/Main;");
    // foreach(class: classes) {
    //     io::printfn("ref:%s", class.ref);
    //     io::printfn("type_id:%s", class.id);
    //     io::printfn("signature:%s", class.signature);
    //     io::printfn("status:%s\n", class.status);
    // }
}
