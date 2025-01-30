import std::io;
import jdwp;

// First start the debugger, through java or gradle
// JVM ARGS -agentlib:jdwp=transport=dt_socket,server=y,address=8000,suspend=n,quiet=y
// GRADLE ARGS --rerun-tasks test --debug-jvm

fn void main(String[] args)
{
    Jdwp jdwp = Jdwp.new();
    defer jdwp.close()!!;
    VersionReply r = jdwp.vm_version()!!;
    io::printfn("description: %s", r.description);
    io::printfn("major: %d", r.jdwp_major);
    io::printfn("minor: %d", r.jdwp_minor);
    io::printfn("vm_version: %s", r.vm_version);
    io::printfn("vm_name: %s", r.vm_name);


    // jdwp.vm_classes_by_signature("Ljava/lang/String;")!!;
    // jdwp.vm_all_classes()!!;
    // jdwp.vm_create_string("robin")!!;
    // jdwp.vm_create_string("tordly")!!;

    // char[] encoded = encode_int(155);
    // foreach(c: encoded) io::printf("%02X ", c);
    // io::printn();
    // io::printfn("%d", decode_int(encoded));
}


fn int decode_int(char[] data)
{
    return ((int)(uint)data[0] << 24) |
           ((int)(uint)data[1] << 16) | 
           ((int)(uint)data[2] << 8)  |
           ((int)(uint)data[3]);
}

fn char[] encode_int(int num)
{
    char[4] length_prefix;
    length_prefix[0] = (char)(num >> 24) & 0xFF;
    length_prefix[1] = (char)(num >> 16) & 0xFF;
    length_prefix[2] = (char)(num >> 8)  & 0xFF;
    length_prefix[3] = (char)(num)       & 0xFF;
    return @clone(length_prefix);
}
