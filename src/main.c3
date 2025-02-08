import std::io;
import jdwp;
import std::thread;
import std::net;
import std::collections::anylist;

// First start the debugger, through java or gradle
// JVM ARGS -agentlib:jdwp=transport=dt_socket,server=y,address=8000,suspend=n,quiet=y
// GRADLE ARGS --rerun-tasks test --debug-jvm

fn void main(String[] args)
{
    event_loop();
    
    // example_set(EventKind.CLASS_PREPARE);
    // example_method();
    // example_all_classes();
    // example_classes_by_signature();
    // example_version();
}

fn void event_loop()
{
    Jdwp jdwp = Jdwp.new();
    defer jdwp.client.close()!!;

    Thread t;
    defer t.join()!!;
    t.create((ThreadFn) &Jdwp.start_event_loop, &jdwp)!!;

    while RUNNING: (true) {
        String[] input = io::readline()!!.trim().tsplit(" ");
        switch (input[0]) {
            case "version": 
                int id = jdwp.seq += 1;
                jdwp.intos[id] = (Into)&vm::version;
                jdwp.vm_version(id);
                while (!jdwp.replies.has_key(id)){}; // TODO: add timeout
                Version *v = anycast(jdwp.replies[id]!!, Version)!!;
                io::printfn("%s", v);
            case "classes":
                switch (input[1]) {
                    case "all":
                        int id = jdwp.seq += 1;
                        jdwp.intos[id] = (Into)&vm::all_classes;
                        jdwp.vm_all_classes(id);
                        while (!jdwp.replies.has_key(id)){}; // TODO: add timeout
                        Class[]* classes = anycast(jdwp.replies[id]!!, Class[])!!;
                        foreach(idx, class: classes) io::printfn("%d:\n%s", idx, class);
                    default:
                        int id = jdwp.seq += 1;
                        jdwp.intos[id] = (Into)&vm::classes_by_signature;
                        jdwp.classes_by_signature(id, input[1]);
                        // jdwp.classes_by_signature(id, "Ljava/lang/Object;");
                        while (!jdwp.replies.has_key(id)){}; // TODO: add timeout
                        if(!jdwp.replies[id]!!) continue RUNNING;
                        Class[]* classes = anycast(jdwp.replies[id]!!, Class[])!!;
                        foreach(idx, class: classes) io::printfn("%d:\n%s", idx, class);
                }
            case "debug":
                jdwp.toggle_debug();
            case "quit": 
            case "exit": 
                jdwp.stop();
                break RUNNING;
            default: 
                io::printfn("%s not implemented", input);
        }
    }
}

fn void example_set(EventKind event)
{
    Jdwp jdwp = Jdwp.new();
    defer jdwp.stop();

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

// fn void example_all_classes()
// {
//     Jdwp jdwp = Jdwp.new();
//     defer jdwp.stop();
//
//     jdwp.vm_all_classes();
    // Class[] classes = jdwp.vm_all_classes();
    // foreach(class: classes) {
        // io::printfn("ref:%s", class.ref);
        // io::printfn("type_id:%s", class.id);
        // io::printfn("signature:%s", class.signature);
        // io::printfn("status:%s\n", class.status);
    // }
// }

// fn void example_method()
// {
//     Jdwp jdwp = Jdwp.new();
//     defer jdwp.stop()!!;
//
//     Class[] classes = jdwp.vm_classes_by_signature("Lapp/MainTest;")!!;
//     foreach(class: classes) {
//         io::printfn("ref:%s", class.ref);
//         io::printfn("type_id:%s", class.id);
//         io::printfn("signature:%s", class.signature);
//         io::printfn("status:%s\n", class.status);
//     }
// }

// fn void example_classes_by_signature()
// {
//     Jdwp jdwp = Jdwp.new();
//     defer jdwp.stop();
//
    // Class[] classes = jdwp.vm_classes_by_signature("Ljava/lang/String;")!!;
    // jdwp.vm_classes_by_signature("Lhello/Main;");
    // Class[] classes = jdwp::vm_classes_by_signature("Lhello/Main;");
    // foreach(class: classes) {
    //     io::printfn("ref:%s", class.ref);
    //     io::printfn("type_id:%s", class.id);
    //     io::printfn("signature:%s", class.signature);
    //     io::printfn("status:%s\n", class.status);
    // }
// }
