module jdwp::referencetype;

import jdwp;

struct Method
{
    Id id;
    String name;
    String signature;
    int mod_bits; // access flags
}

fn void Jdwp.methods(&self, int id, Class class)
{
    Command cmd = { 11 + 8, id, 0, 2, 5 };
    self.send(cmd, class.id[..])!!;
}

fn any methods(Reply *reply)
{
    char[] data = reply.body[:reply.length];
    int offset = 0;
    int declared = jdwp::decode_int(data, &offset)!!;
    Method[] methods = mem::new_array(Method, declared);

    for (int i = 0; i< declared; i++) {
        methods[i] = {
            .id = jdwp::decode_id(data, &offset)!!,
            .name = jdwp::decode_string(data, &offset)!!,
            .signature = jdwp::decode_string(data, &offset)!!,
            .mod_bits = jdwp::decode_int(data, &offset)!!,
        };
    }
    return @clone(methods);
}


enum AccessFlag 
{
    PUBLIC,     // 0x0001
    FINAL,      // 0x0010
    SUPER,      // 0x0020
    INTERFACE,  // 0x0200
    ABSTRACT,   // 0x0400
    SYNTHETIC,  // 0x1000
    ANNOTATION, // 0x2000
    ENUM,       // 0x4000
}
