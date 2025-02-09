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
        if (input.len == 1) {
            switch (input[0]) {
                case "version": 
                    int id = jdwp.seq += 1;
                    jdwp.intos[id] = (Into)&vm::version;
                    jdwp.vm_version(id);
                    while (!jdwp.replies.has_key(id)){}; // TODO: add timeout
                    Version *v = anycast(jdwp.replies[id]!!, Version)!!;
                    io::printfn("%s", v);
                case "classes":
                    int id = jdwp.seq += 1;
                    jdwp.intos[id] = (Into)&vm::all_classes;
                    jdwp.vm_all_classes(id);
                    while (!jdwp.replies.has_key(id)){}; // TODO: add timeout
                    Class[]* classes = anycast(jdwp.replies[id]!!, Class[])!!;
                    // foreach(idx, class: classes) io::printfn("%d:\n%s", idx, class);
                    foreach(idx, class: classes) io::printfn("%d: %s", idx, class.signature);
                case "debug":
                    jdwp.toggle_debug();
                case "quit": 
                case "exit": 
                    jdwp.stop();
                    break RUNNING;
                default: 
                    io::printfn("%s not implemented", input);
            }
        } else if (input.len >= 2) {
            switch (input[0]) {
                case "classes":
                    int id = jdwp.seq += 1;
                    jdwp.intos[id] = (Into)&vm::classes_by_signature;
                    jdwp.classes_by_signature(id, input[1]);
                    while (!jdwp.replies.has_key(id)){}; // TODO: add timeout
                    if(!jdwp.replies[id]!!) continue RUNNING;
                    Class[]* classes = anycast(jdwp.replies[id]!!, Class[])!!;
                    foreach(idx, class: classes) io::printfn("%d:\n%s", idx, class);
                case "subscribe":
                    switch (input[1]) {
                        case "thread_start":
                            int id = jdwp.seq += 1;
                            RequestSet set = {
                                .event_kind = (char) EventKind.THREAD_START.code,
                                .suspend_policy = (char) SuspendPolicy.NONE.code,
                                .modifiers_count = 0,
                            };
                            jdwp.set(id, set, null);
                        case "class_prepare":
                            int id = jdwp.seq += 1;
                            jdwp.intos[id] = (Into)&event::set;
                            RequestSet set = {
                                .event_kind = (char) EventKind.CLASS_PREPARE.code,
                                .suspend_policy = (char) SuspendPolicy.NONE.code,
                                .modifiers_count = 0,
                            };
                            if (input.len == 3) {
                                set.modifiers_count = 1;
                                RequestSetModifier mod = {
                                    .kind = ModifierType.CLASS_MATCH.code,
                                    .string = input[2], // *.Hello
                                };
                                jdwp.set(id, set, &mod);
                            } else {
                                jdwp.set(id, set, null);
                            }
                            while (!jdwp.replies.has_key(id)){}; // TODO: add timeout
                            if(!jdwp.replies[id]!!) continue RUNNING;
                            int* request_id = anycast(jdwp.replies[id]!!, int)!!;
                            io::printfn("%d", *request_id);
                    }
            }
        }
    }
}

