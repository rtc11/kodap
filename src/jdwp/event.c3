module jdwp::event;

import jdwp;
import std::io;


// [Command][RequestSet][RequestSetModifier][RequestSetModifier][..]
fn void Jdwp.set(&self, RequestSet set, RequestSetModifier mod)
{
    char[] mod_ch = mod.to_char();
    Command cmd = { 11 + $sizeof(set) + mod_ch.len, self.seq+=1, 0, 15, 1 };
    char[] set_mods = array::tconcat((char[6])set, mod_ch);
    self.send(cmd, set_mods)!!;
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
            // char[4] buf;
            // char[1] kind = {self.kind};
            // bitorder::write(self.count, &buf, IntBE);
            // return array::tconcat(kind, buf[..]);
            return bits;
        case ModifierType.CLASS_MATCH.code: 
        case ModifierType.LOCATION_ONLY.code:
            char[] bits = (char[1]*) self;
            char[] str = jdwp::encode_string((String) self.string);
            return array::tconcat(bits, str); 
    }

    return {};
}

// fn int! Jdwp.set_breakpoint(&self, Class class, Method method)
// {
//     RequestSet break_point = {
//         .event_kind = EventKind.BREAKPOINT.code,
//         .suspend_policy = SuspendPolicy.ALL.code,
//         .modifiers_count = 1,
//     };
//
//     Location location = {
//         .type_tag = TypeTag.CLASS.code,
//         .class_id = class.id.to_long(),
//         .method_id = method.id.to_long(),
//     };
//
//     char* location_ptr = mem::malloc($sizeof(location));
//     char[] location_buf = location_ptr[..$sizeof(location)-1];
//     // todo: putt location inn i location_buf
//     RequestSetModifier modifier = {
//         .kind = ModifierType.LOCATION_ONLY.code,
//         .string = (String) location_buf,
//     };
//
//     return self.set(break_point, modifier);
// }

bitstruct Location: char[25]
{
    char type_tag:  0..7;    // TypeTag
    long class_id:  8..71;   // Id
    long method_id: 72..135; // Id
    long location:  136..199;//
}

fn void Jdwp.clear(&self)
{

}

fn void Jdwp.clear_all_breakpoints(&self)
{

}

