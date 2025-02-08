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
    int offset = 0;
    Version* version = mem::new(Version, {
        .description = jdwp::decode_string(data, &offset)!!,
        .jdwp_major = jdwp::decode_int(data, &offset)!!,
        .jdwp_minor = jdwp::decode_int(data, &offset)!!,
        .vm_version = jdwp::decode_string(data, &offset)!!,
        .vm_name = jdwp::decode_string(data, &offset)!!,
    });

    return (any) version;
} 

struct Class
{
    TypeTag ref;
    Id id;            // type_id
    String signature; // JNI signature (decoded)
    ClassStatus status;
}

fn usz! Class.to_format(&self, Formatter* f) @dynamic
{
    return f.printf(`ref:       %s
id:        %s
signature: %s
status:    %s`,
        self.ref,
        self.id,
        self.signature,
        self.status,
    );
}
fn void Jdwp.classes_by_signature(&self, int id, String signature = "Ljava/lang/Object;")
{
    char[] data = jdwp::encode_string(signature);
    Command cmd = { 11 + data.len, id, 0, 1, 2 };
    self.send(cmd, data)!!;
}

fn any classes_by_signature(Reply* reply)
{
    char[] data = reply.body[:reply.length];
    int offset = 0;
    int size = jdwp::decode_int(data, &offset)!!;
    if (size == 0) return {};
    Class[] classes = mem::new_array(Class, size);

    int actual_size = 0;
    for(int i = 0; i < size; i++) {
        TypeTag type_tag;
        char tag = jdwp::decode_char(data, &offset)!!;
        switch (tag) {
            case 1: type_tag = CLASS;
            case 2: type_tag = INTERFACE; 
            case 3: type_tag = ARRAY;
            default: io::printfn("type_tag not set, found: %d", tag);
        }
        Id type_id = jdwp::decode_id(data, &offset)!!;

        ClassStatus status;
        int st = jdwp::decode_int(data, &offset)!!;
        if (st & 0x01) status = VERIFIED;
        if (st & 0x02) status = PREPARED;
        if (st & 0x04) status = INITIALIZED;
        if (st & 0x08) status = ERROR;

        classes[i] = {
            .ref = type_tag,
            .id = type_id,
            .status = status,
        };
    }

    return @clone(classes);
}

fn void Jdwp.vm_all_classes(&self, int id) => self.send({ 11 , id, 0, 1, 3 })!!;
fn any all_classes(Reply *reply)
{
    char[] data = reply.body[:reply.length];
    int offset = 0;
    int size = jdwp::decode_int(data, &offset)!!;
    Class[] classes = mem::new_array(Class, size);
    if (size == 0) return null;

    int actual_size = 0;
    for(int i = 0; i < size; i++) {
        TypeTag type_tag;
        char tag = jdwp::decode_char(data, &offset)!!;
        switch (tag) {
            case 1: type_tag = CLASS;
            case 2: type_tag = INTERFACE; 
            case 3: type_tag = ARRAY;
            default: io::printfn("type_tag not set, found: %d", tag);
        }
        Id type_id = jdwp::decode_id(data, &offset)!!;
        String signature = jdwp::decode_string(data, &offset)!!; 

        ClassStatus status;
        int st = jdwp::decode_int(data, &offset)!!;
        if (st & 0x01) status = VERIFIED;
        if (st & 0x02) status = PREPARED;
        if (st & 0x04) status = INITIALIZED;
        if (st & 0x08) status = ERROR;

        classes[i] = {
            .ref = type_tag,
            .id = type_id,
            .signature = signature,
            .status = status,
        };
    }

    return @clone(classes);
}

fn void Jdwp.vm_all_threads(&self, int id) =>  self.send({ 11, id, 0, 1, 4 })!!;
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

