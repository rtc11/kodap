module jdwp::vm;

import jdwp;
import std::io;

bitstruct LineTableRequest: char[16] @bigendian
{
    long ref_type:  0..63;   // EventKind
    long method_id: 64..127; // SuspendPolicy
}

struct Line
{
    long line_code_idx;
    int line_num;
}

struct LineTable
{
    long start;
    long end;
    Line[] lines;
}

fn void Jdwp.line_tables(&self, int id, Id class, Id method)
{
    LineTableRequest req = { 
        .ref_type = class.to_long(),
        .method_id = method.to_long(),
    };
    char[] data = (char[16]*) &req;
    self.send({ 11 + data.len, id, 0, 6, 1 }, data)!!;
}

fn any line_tables(Reply *reply)
{
    char[] data = reply.body[:reply.length];
    int offset = 0;
    long start = jdwp::decode_long(data, &offset)!!;
    long end = jdwp::decode_long(data, &offset)!!;
    int size = jdwp::decode_int(data, &offset)!!;
    Line[] lines = mem::new_array(Line, size);
    for(int i = 0; i<size; i++) {
        lines[i] = {
            .line_code_idx = jdwp::decode_long(data, &offset)!!,
            .line_num = jdwp::decode_int(data, &offset)!!,
        };
    }

    LineTable lt = {
        .start = start,
        .end = end,
        .lines = lines,
    };

    return @clone(lt);
}

