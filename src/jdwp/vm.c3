module jdwp::vm;

import jdwp;
import std::io;
import std::net::os;

struct Version
{
    String description;
    int jdwp_major;
    int jdwp_minor;
    String vm_version;
    String vm_name;
}

fn void Jdwp.vm_version(&self) => self.send({ 11, self.seq+=1, 0, 1, 1 })!!;

fn Version vm_version(char[] data) 
{
    Version reply;
    int offset = 0;

    reply.description = jdwp::decode_string(data)!!;
    offset += 4 + reply.description.len;

    reply.jdwp_major = jdwp::decode_int(data[offset..])!!;
    offset += 4;

    reply.jdwp_minor = jdwp::decode_int(data[offset..])!!;
    offset += 4;

    reply.vm_version = jdwp::decode_string(data[offset..])!!;
    offset += 4 + reply.vm_version.len;

    reply.vm_name = jdwp::decode_string(data[offset..])!!;

    return reply;
} 

struct Class
{
    TypeTag ref;
    Id id;            // type_id
    String signature; // JNI signature (decoded)
    ClassStatus status;
}

fn void Jdwp.vm_classes_by_signature(&self, String signature = "Ljava/lang/Object;")
{
    Command cmd = { 11 + 4 + signature.len, self.seq+=1, 0, 1, 2 };
    self.send(cmd, jdwp::encode_string(signature))!!;
}

fn Class[] vm_classes_by_signature(char[] data, String signature = "Ljava/lang/Object;")
{
    int offset = 0;
    int size = jdwp::decode_int(data[..offset+3])!!;
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

        Id type_id = jdwp::decode_id(data[offset..offset+8])!!;
        offset+=8;
        ClassStatus status;
        int st = jdwp::decode_int(data[offset..])!!;
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

fn void Jdwp.vm_all_classes(&self)
{
    Command cmd = { 11 , self.seq+=1, 0, 1, 3 };
    self.send(cmd)!!;
}

fn Class[] vm_all_classes(char[] data)
{
    int offset = 0;
    int size = jdwp::decode_int(data[offset..offset+3])!!;
    offset+=4;
    if (size == 0) return {};
    Class[] classes = mem::new_array(Class, size);

    int actual_size = 0;
    for(int i = 0; i < size; i++) {
        TypeTag type_tag;
        char tag = data[offset++];
        switch (tag) {
            case 1: type_tag = CLASS;
            case 2: type_tag = INTERFACE; 
            case 3: type_tag = ARRAY;
            default: io::printfn("type_tag not set, found: %d", tag);
        }

        Id type_id = jdwp::decode_id(data[offset..offset+7])!!;
        offset+=8;

        String signature = jdwp::decode_string(data[offset..])!!; 
        offset += 4 + signature.len;

        ClassStatus status;
        int st = jdwp::decode_int(data[offset..offset+3])!!;
        if (st & 0x01) status = VERIFIED;
        if (st & 0x02) status = PREPARED;
        if (st & 0x04) status = INITIALIZED;
        if (st & 0x08) status = ERROR;
        offset+=4;

        classes[i] = {
            .ref = type_tag,
            .id = type_id,
            .signature = signature,
            .status = status,
        };
    }

    return classes;
}
// fn String! Jdwp.vm_all_classes(&self) => self.exchange({ 11, self.seq+=1, 0, 1, 3 })!;
fn void Jdwp.vm_all_threads(&self) => self.send({ 11, self.seq+=1, 0, 1, 4 })!!;
fn void Jdwp.vm_top_level_thread_groups(&self) => self.send({ 11, self.seq+=1, 0, 1, 5 })!!;
fn void Jdwp.vm_dispose(&self) => self.send({ 11, self.seq+=1, 0, 1, 6 })!!;
fn void Jdwp.vm_id_sizes(&self) => self.send({ 11, self.seq+=1, 0, 1, 7 })!!;
fn void Jdwp.vm_suspend(&self) => self.send({ 11, self.seq+=1, 0, 1, 8 })!!;
fn void Jdwp.vm_resume(&self) => self.send({ 11, self.seq+=1, 0, 1, 9 })!!;
fn void Jdwp.vm_exit(&self) => self.send({ 11, self.seq+=1, 0, 1, 10 })!!;
// fn String Jdwp.vm_create_string(&self, String str)
// {
//     // header size 11 + 4-byte length prefix for string + string length
//     Command cmd = { 11 + 4 + str.len, self.seq+=1, 0, 1, 11 };
//     return self.exchange(cmd, jdwp::encode_string(str))!!;
// }

