import std::io;
import jdwp;

// First start the debugger, through java or gradle
// JVM ARGS -agentlib:jdwp=transport=dt_socket,server=y,address=8000,suspend=n,quiet=y
// GRADLE ARGS --rerun-tasks test --debug-jvm

fn void main(String[] args)
{
    Jdwp jdwp = Jdwp.new();
    defer jdwp.close()!!;
    jdwp.vm_version()!!;
    jdwp.vm_classes_by_signature("Ljava/lang/String;")!!;
}



