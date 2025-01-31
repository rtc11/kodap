module jdwp::eventrequest;

import jdwp;

fn int! Jdwp.set(&self, Class class, Method method)
{
    Breakpoint bp = {
        .event_kind = EventKind.BREAKPOINT.code,
        .suspend_policy = SuspendPolicy.ALL.code,
        .modifiers_count = 1,
        .modifier_type = ModifierType.LOCATION_ONLY.code,
    };
    Location location = {
        .type_tag = TypeTag.CLASS.code,
        .class_id = class.id.to_long(),
        .method_id = method.id.to_long(),
    };
    Command cmd = { 11 + $sizeof(bp) + $sizeof(location), self.seq++, 0, 15, 1 };
    self.send(cmd, (char[25]*) &location)!;
    char[] data = self.read()!;
    return jdwp::decode_int(data)!;
}

bitstruct Breakpoint: char[7]
{
    char event_kind:      0..7;   // EventKind
    char suspend_policy:  8..15;  // SuspendPolicy
    int  modifiers_count: 16..47;
    char modifier_type:   48..55; // ModifierType
}


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

