import std::io;
import libc;
import event::libc;

fn void main(String[] args)
{
    String filename = "README.md";
	File f = file::open(filename, "r")!!;
	defer (void)f.close();

    Fd fd = libc::fileno(f.file);
    defer libc::close(fd);

    int kq = libc::kqueue();
    defer libc::close(kq);

    Kevent change = { 
        .ident = fd,
        .filter = EvFilter.VNODE.code,
        .flags = Ev.ADD.code | Ev.ENABLE.code | Ev.CLEAR.code,
        .fflags = Note.WRITE.code | Note.EXTEND.code | Note.ATTRIB.code,
        .data = 0,
        .udata = null,
    };

    io::printfn("watching '%s' for modifications..", filename);

    while LISTEN : (true) {
        Kevent event;
        int nev = libc::kevent(kq, &change, 1, &event, 1, null);
        if (nev == -1) {
            io::printfn("ERROR: kevent failed");
            break LISTEN;
        }

        foreach(ff: event.get_fflags()) {
            switch(ff) {
                case Note.WRITE: io::printn("File was modified!");
                case Note.EXTEND: io::printn("File was extended");
                case Note.ATTRIB: io::printn("File attributes changed");
                default: io::printfn("File event %s", ff);
            }
        }
    }
}

