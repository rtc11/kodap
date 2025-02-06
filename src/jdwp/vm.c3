module jdwp::vm;

import jdwp;
import std::io;
import std::net::os;
import std::collections::anylist;

struct Version (Printable)
{
    String description;
    int jdwp_major;
    int jdwp_minor;
    String vm_version;
    String vm_name;
}

fn usz! Version.to_format(&self, Formatter* f) @dynamic
{
    return f.printf(`%s
JDWP: %d.%d
JVM:  %s
JDK:  %s`,
        self.description,
        self.jdwp_major,
        self.jdwp_minor,
        self.vm_version,
        self.vm_name,
    );
}

fn void Jdwp.vm_version(&self, int id) => self.send({ 11, id, 0, 1, 1 })!!;

fn any version(Reply *reply) 
{
    char[] data = reply.body[:reply.length];
    Version* version = mem::new(Version);
    int offset = 0;

    version.description = jdwp::decode_string(data)!!;
    offset += 4 + version.description.len;

    version.jdwp_major = jdwp::decode_int(data[offset..])!!;
    offset += 4;

    version.jdwp_minor = jdwp::decode_int(data[offset..])!!;
    offset += 4;

    version.vm_version = jdwp::decode_string(data[offset..])!!;
    offset += 4 + version.vm_version.len;

    version.vm_name = jdwp::decode_string(data[offset..])!!;

    return (any) version;
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

fn void Jdwp.vm_all_classes(&self, int id)
{
    Command cmd = { 11 , id, 0, 1, 3 };
    self.send(cmd)!!;
}

struct ClassArray
{
    Class[] array;
}

fn any all_classes(Reply *reply)
{
    char[] data = reply.body[:reply.length];
    int offset = 0;
    int size = jdwp::decode_int(data[offset..offset+3])!!;
    offset+=4;
    if (size == 0) return {};
    Class[] classes = mem::new_array(Class, size);
    // Class* classes = mem::new_array(Class, size);

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

    ClassArray* ca = mem::new_with_padding(ClassArray, Class.sizeof * size);
    ca.array = classes;
    return (any) ca;
}

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

