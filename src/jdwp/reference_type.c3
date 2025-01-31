module jdwp::referencetype;

import jdwp;

struct Method
{
    Id id;
    String name;
    String signature;
    int mod_bits; // access flags
}

fn Method[]! Jdwp.methods(&self, Class class)
{
    Command cmd = { 11 + 8, self.seq++, 0, 2, 5 };
    self.send(cmd, class.id[..])!;

    char[] data = self.read()!;
    int offset = 0;
    int declared = jdwp::decode_int(data[..offset+=4])!;
    Method* method_ptrs = mem::new_array(Method, declared);

    for (int i = 0; i< declared; i++) {
        Method m;
        m.id = jdwp::decode_id(data[offset..offset+=8])!;
        m.name = jdwp::decode_string(data[offset..])!;
        offset += 4 + m.name.len;
        m.signature = jdwp::decode_string(data[offset..])!;
        offset += 4 + m.signature.len;
        m.mod_bits = jdwp::decode_int(data[offset..])!;
        offset+=4;
        method_ptrs[i] = m;
    }

    return method_ptrs[..declared];
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
