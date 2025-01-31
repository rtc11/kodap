module jdwp::vm;

import jdwp;
import std::io;

struct Version
{
    String description;
    int jdwp_major;
    int jdwp_minor;
    String vm_version;
    String vm_name;
}

fn Version! Jdwp.vm_version(&self) 
{
    self.send({ 11, self.seq++, 0, 1, 1 })!;
    char[] data = self.read()!;

    Version reply;
    int offset = 0;

    reply.description = jdwp::decode_string(data)!;
    offset += 4 + reply.description.len;

    reply.jdwp_major = jdwp::decode_int(data[offset..])!;
    offset += 4;

    reply.jdwp_minor = jdwp::decode_int(data[offset..])!;
    offset += 4;

    reply.vm_version = jdwp::decode_string(data[offset..])!;
    offset += 4 + reply.vm_version.len;

    reply.vm_name = jdwp::decode_string(data[offset..])!;

    return reply;
} 

struct Class
{
    TypeTag ref;
    Id id;            // type_id
    String signature; // JNI signature (decoded)
    ClassStatus status;
}

fn Class[]! Jdwp.vm_classes_by_signature(&self, String signature = "Ljava/lang/Object;")
{
    // header size 11 + 4-byte length prefix for string + string length
    Command cmd = { 11 + 4 + signature.len, self.seq++, 0, 1, 2 };
    self.send(cmd, jdwp::encode_string(signature))!;
    char[] data = self.read()!;

    int offset = 0;
    int size = jdwp::decode_int(data[..offset+3])!;
    if (size == 0) return {};
    offset+=4;
    Class* cls_ptrs = mem::new_array(Class, size);

    for(int i = 0; i < size; i++) {
        TypeTag type_tag;
        char tag = data[offset];
        switch (tag) {
            case 1: type_tag = CLASS;
            case 2: type_tag = INTERFACE; 
            case 3: type_tag = ARRAY;
            default: io::printfn("type_tag not set, found: %d", tag);
        }
        offset++;

        // long type_id = jdwp::decode_long(data[offset..])!;
        Id type_id = jdwp::decode_id(data[offset..offset+8])!;
        offset+=8;
        ClassStatus status;
        int st = jdwp::decode_int(data[offset..])!;
        if (st & 0x01) status = VERIFIED;
        if (st & 0x02) status = PREPARED;
        if (st & 0x04) status = INITIALIZED;
        if (st & 0x08) status = ERROR;
        offset+=4;

        cls_ptrs[i] = {
            .ref = type_tag,
            .id = type_id,
            .signature = signature,
            .status = status,
        };
    }
    
    return cls_ptrs[..size-1];
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
    return self.exchange(cmd, jdwp::encode_string(str))!;
}

