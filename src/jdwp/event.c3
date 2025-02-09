module jdwp::event;

import jdwp;
import std::io;


fn any set(Reply *reply)
{
    char[] data = reply.body[:reply.length];
    int offset = 0;
    int request_id = jdwp::decode_int(data, &offset)!!;
    return @clone(request_id);
}

fn void Jdwp.set(&self, int id, RequestSet set, RequestSetModifier* mod)
{
    if(mod) {
        char[] mod_ch = mod.to_char();
        Command cmd = { 11 + $sizeof(set) + mod_ch.len, id, 0, 15, 1 };
        char[] set_mods = array::tconcat((char[6])set, mod_ch);
        self.send(cmd, set_mods)!!;
    } else {
        Command cmd = { 11 + $sizeof(set), id, 0, 15, 1 };
        self.send(cmd, (char[6]*) &set)!!;
    }
}

bitstruct RequestSet: char[6] @bigendian
{
    char event_kind:      0..7;   // EventKind
    char suspend_policy:  8..15;  // SuspendPolicy
    uint  modifiers_count: 16..47;
}

struct RequestSetModifier
{
    bitstruct : char[17] @overlap // @bigendian
    {
        char kind:              0..7; // ModifierType

        uint count:             8..39;
        uint expr_id:           8..39;
        long clazz:             8..71;
        long exception_or_null: 8..71;
        char caught:            8..15;
        char uncaught:          8..15;

        long declaring:         8..71;
        long field_id:          72..135;

        long thread:            8..71;
        int size:               72..103;
        int depth:              104..135;

        long instance:          8..71;
    }

    char[] string; // kind 5, 6, 12
}

fn char[] RequestSetModifier.to_char(&self)
{
    switch (self.kind) {
        case ModifierType.COUNT.code:
            char[] bits = (char[5]*) self;
            return bits;
        case ModifierType.CLASS_MATCH.code: 
        case ModifierType.LOCATION_ONLY.code:
            char[] bits = (char[1]*) self;
            char[] str = jdwp::encode_string((String) self.string);
            return array::tconcat(bits, str); 
    }

    return {};
}

