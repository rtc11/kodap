module event::libc;

import libc;
import std::io;
import std::collections::list;

extern fn int kqueue();
extern fn int kevent(int kq, Kevent *changelist, int nchanges, Kevent *eventlist, int nevents, TimeSpec *timeout);

struct Kevent
{
     uptr   ident;  /* identifier for this event */
     short  filter; /* filter for event */
     ushort flags;  /* general flags */
     uint   fflags; /* filter-specific flags */
     iptr   data;   /* filter-specific data */
     void   *udata; /* opaque user data identifier */
}

fn Ev[] Kevent.get_flags(&self)
{
    List(<Ev>) evs;
    if (self.flags & Ev.ADD.code == Ev.ADD.code) evs.push(Ev.ADD);
    if (self.flags & Ev.DELETE.code == Ev.DELETE.code) evs.push(Ev.DELETE);
    if (self.flags & Ev.ENABLE.code == Ev.ENABLE.code) evs.push(Ev.ENABLE);
    if (self.flags & Ev.DISABLE.code == Ev.DISABLE.code) evs.push(Ev.DISABLE);
    if (self.flags & Ev.ONESHOT.code == Ev.ONESHOT.code) evs.push(Ev.ONESHOT);
    if (self.flags & Ev.CLEAR.code == Ev.CLEAR.code) evs.push(Ev.CLEAR);
    if (self.flags & Ev.RECEIPT.code == Ev.RECEIPT.code) evs.push(Ev.RECEIPT);
    if (self.flags & Ev.DISPATCH.code == Ev.DISPATCH.code) evs.push(Ev.DISPATCH);
    if (self.flags & Ev.UDATA_SPECIFIC.code == Ev.UDATA_SPECIFIC.code) evs.push(Ev.UDATA_SPECIFIC);
    if (self.flags & Ev.DISPATCH2.code == Ev.DISPATCH2.code) evs.push(Ev.DISPATCH2);
    if (self.flags & Ev.VANISHED.code == Ev.VANISHED.code) evs.push(Ev.VANISHED);
    if (self.flags & Ev.SYSFLAGS.code == Ev.SYSFLAGS.code) evs.push(Ev.SYSFLAGS);
    if (self.flags & Ev.FLAG0.code == Ev.FLAG0.code) evs.push(Ev.FLAG0);
    if (self.flags & Ev.FLAG1.code == Ev.FLAG1.code) evs.push(Ev.FLAG1);
    if (self.flags & Ev.EOF.code == Ev.EOF.code) evs.push(Ev.EOF);
    if (self.flags & Ev.ERROR.code == Ev.ERROR.code) evs.push(Ev.ERROR);
    if (self.flags & Ev.POLL.code == Ev.POLL.code) evs.push(Ev.POLL);
    if (self.flags & Ev.OOBAND.code == Ev.OOBAND.code) evs.push(Ev.OOBAND);
    return evs.array_view();
}

fn Note[] Kevent.get_fflags(&self)
{
    List(<Note>) notes;
    switch (self.filter) {
        case EvFilter.USER.code: 
            if (self.fflags & Note.TRIGGER.code == Note.TRIGGER.code) notes.push(Note.TRIGGER);
        case EvFilter.READ.code: 
        case EvFilter.WRITE.code: 
            if (self.fflags & Note.LOWAT.code == Note.LOWAT.code) notes.push(Note.LOWAT);
        case EvFilter.EXCEPT.code: 
            if (self.fflags & Note.OOB.code == Note.OOB.code) notes.push(Note.OOB);
        case EvFilter.VNODE.code: 
            if (self.fflags & Note.DELETE.code == Note.DELETE.code) notes.push(Note.DELETE);
            if (self.fflags & Note.WRITE.code == Note.WRITE.code) notes.push(Note.WRITE);
            if (self.fflags & Note.EXTEND.code == Note.EXTEND.code) notes.push(Note.EXTEND);
            if (self.fflags & Note.ATTRIB.code == Note.ATTRIB.code) notes.push(Note.ATTRIB);
            if (self.fflags & Note.LINK.code == Note.LINK.code) notes.push(Note.LINK);
            if (self.fflags & Note.RENAME.code == Note.RENAME.code) notes.push(Note.RENAME);
            if (self.fflags & Note.REVOKE.code == Note.REVOKE.code) notes.push(Note.REVOKE);
            if (self.fflags & Note.NONE.code == Note.NONE.code) notes.push(Note.NONE);
            if (self.fflags & Note.FUNLOCK.code == Note.FUNLOCK.code) notes.push(Note.FUNLOCK);
            if (self.fflags & Note.LEASE_DOWNGRADE.code == Note.LEASE_DOWNGRADE.code) notes.push(Note.LEASE_DOWNGRADE);
            if (self.fflags & Note.LEASE_RELEASE.code == Note.LEASE_RELEASE.code) notes.push(Note.LEASE_RELEASE);
        case EvFilter.PROC.code: 
        case EvFilter.SIGNAL.code: 
            if (self.fflags & Note.EXIT.code == Note.EXIT.code) notes.push(Note.EXIT);
            if (self.fflags & Note.FORK.code == Note.FORK.code) notes.push(Note.FORK);
            if (self.fflags & Note.EXEC.code == Note.EXEC.code) notes.push(Note.EXEC);
            if (self.fflags & Note.REAP.code == Note.REAP.code) notes.push(Note.REAP);
            if (self.fflags & Note.SIGNAL.code == Note.SIGNAL.code) notes.push(Note.SIGNAL);
            if (self.fflags & Note.EXITSTATUS.code == Note.EXITSTATUS.code) notes.push(Note.EXITSTATUS);
            if (self.fflags & Note.EXIT_DETAIL.code == Note.EXIT_DETAIL.code) notes.push(Note.EXIT_DETAIL);
            if (self.fflags & Note.PDATAMASK.code == Note.PDATAMASK.code) notes.push(Note.PDATAMASK);
        case EvFilter.VM.code: 
            if (self.fflags & Note.VM_PRESSURE.code == Note.VM_PRESSURE.code) notes.push(Note.VM_PRESSURE);
            if (self.fflags & Note.VM_PRESSURE_TERMINATE.code == Note.VM_PRESSURE_TERMINATE.code) notes.push(Note.VM_PRESSURE_TERMINATE);
            if (self.fflags & Note.VM_PRESSURE_SUDDEN_TERMINATE.code == Note.VM_PRESSURE_SUDDEN_TERMINATE.code) notes.push(Note.VM_PRESSURE_SUDDEN_TERMINATE);
            if (self.fflags & Note.VM_ERROR.code == Note.VM_ERROR.code) notes.push(Note.VM_ERROR);
        case EvFilter.TIMER.code: 
            if (self.fflags & Note.SECONDS.code == Note.SECONDS.code) notes.push(Note.SECONDS);
            if (self.fflags & Note.USECONDS.code == Note.USECONDS.code) notes.push(Note.USECONDS);
            if (self.fflags & Note.NSECONDS.code == Note.NSECONDS.code) notes.push(Note.NSECONDS);
            if (self.fflags & Note.ABSOLUTE.code == Note.ABSOLUTE.code) notes.push(Note.ABSOLUTE);
            if (self.fflags & Note.LEEWAY.code == Note.LEEWAY.code) notes.push(Note.LEEWAY);
            if (self.fflags & Note.CRITICAL.code == Note.CRITICAL.code) notes.push(Note.CRITICAL);
            if (self.fflags & Note.BACKGROUND.code == Note.BACKGROUND.code) notes.push(Note.BACKGROUND);
            if (self.fflags & Note.MACH_CONTINUOUS_TIME.code == Note.MACH_CONTINUOUS_TIME.code) notes.push(Note.MACH_CONTINUOUS_TIME);
            if (self.fflags & Note.MACHTIME.code == Note.MACHTIME.code) notes.push(Note.MACHTIME);
        default:
            if (self.fflags & Note.FFNOP.code == Note.FFNOP.code) notes.push(Note.FFNOP);
            if (self.fflags & Note.FFAND.code == Note.FFAND.code) notes.push(Note.FFAND);
            if (self.fflags & Note.FFOR.code == Note.FFOR.code) notes.push(Note.FFOR);
            if (self.fflags & Note.FFCOPY.code == Note.FFCOPY.code) notes.push(Note.FFCOPY);
            if (self.fflags & Note.FFCTRLMASK.code == Note.FFCTRLMASK.code) notes.push(Note.FFCTRLMASK);
            if (self.fflags & Note.FFLAGSMASK.code == Note.FFLAGSMASK.code) notes.push(Note.FFLAGSMASK);
    }
    return notes.array_view();
}

enum EvFilter : (int code)
{
    READ     = -1,
    WRITE    = -2,
    AIO      = -3  , /* attached to aio requests */
    VNODE    = -4  , /* attached to vnodes */
    PROC     = -5  , /* attached to struct proc */
    SIGNAL   = -6  , /* attached to struct proc */
    TIMER    = -7  , /* timers */
    MACHPORT = -8  , /* Mach portsets */
    FS       = -9  , /* Filesystem events */
    USER     = -10 , /* User events */
    VM       = -12 , /* Virtual memory events */
    EXCEPT   = -15 , /* Exception events */
}

enum Ev : (ushort code)
{
    ADD             =       0x0001,      /* add event to kq (implies enable) */
    DELETE          =       0x0002,      /* delete event from kq */
    ENABLE          =       0x0004,      /* enable event */
    DISABLE         =       0x0008,      /* disable event (not reported) */
    ONESHOT         =       0x0010,      /* only report one occurrence */
    CLEAR           =       0x0020,      /* clear event state after reporting */
    RECEIPT         =       0x0040,      /* force immediate event output */
    DISPATCH        =       0x0080,      /* disable event after reporting */
    UDATA_SPECIFIC  =       0x0100, /* unique kevent per udata value */
    DISPATCH2       =       (0x0080 | 0x0100),
    VANISHED        =       0x0200,      /* report that source has vanished  */
    SYSFLAGS        =       0xF000,      /* reserved by system */
    FLAG0           =       0x1000,      /* filter-specific flag */
    FLAG1           =       0x2000,      /* filter-specific flag */
    EOF             =       0x8000,      /* EOF detected */
    ERROR           =       0x4000,      /* error, data contains errno */
    POLL            =       0x1000,
    OOBAND          =       0x2000,
}
 
enum Note: (uint code)
{
    TRIGGER                      = 0x01000000,
    FFNOP                        = 0x00000000, // ignore input fflags
    FFAND                        = 0x40000000, // and fflags
    FFOR                         = 0x80000000, // or fflags
    FFCOPY                       = 0xc0000000, // copy fflags
    FFCTRLMASK                   = 0xc0000000, // mask for operations
    FFLAGSMASK                   = 0x00ffffff,
    LOWAT                        = 0x00000001, // low water mark
    OOB                          = 0x00000002, // exception event
    DELETE                       = 0x00000001, // vnode was removed
    WRITE                        = 0x00000002, // data contents changed
    EXTEND                       = 0x00000004, // size increased
    ATTRIB                       = 0x00000008, // attributes changed
    LINK                         = 0x00000010, // link count changed
    RENAME                       = 0x00000020, // vnode was renamed
    REVOKE                       = 0x00000040, // vnode access was revoked
    NONE                         = 0x00000080, // No specific vnode event: to test for EVFILT_READ activation
    FUNLOCK                      = 0x00000100, // vnode was unlocked by flock(2)
    LEASE_DOWNGRADE              = 0x00000200, // lease downgrade requested
    LEASE_RELEASE                = 0x00000400, // lease release requested
    EXIT                         = 0x80000000, // process exited
    FORK                         = 0x40000000, // process forked
    EXEC                         = 0x20000000, // process exec'd
    REAP                         = 0x10000000, // process reaped
    SIGNAL                       = 0x08000000, // shared with EVFILT_SIGNAL
    EXITSTATUS                   = 0x04000000, // exit status to be returned, valid for child process or when allowed to signal target pid
    EXIT_DETAIL                  = 0x02000000, // provide details on reasons for exit
    PDATAMASK                    = 0x000fffff, // mask for signal & exit status
    EXIT_DETAIL_MASK             = 0x00070000,
    EXIT_DECRYPTFAIL             = 0x00010000,
    EXIT_MEMORY                  = 0x00020000,
    EXIT_CSERROR                 = 0x00040000,
    VM_PRESSURE                  = 0x80000000, // will react on memory pressure
    VM_PRESSURE_TERMINATE        = 0x40000000, // will quit on memory pressure, possibly after cleaning up dirty state
    VM_PRESSURE_SUDDEN_TERMINATE = 0x20000000, // will quit immediately on memory pressure
    VM_ERROR                     = 0x10000000, // there was an error 
    SECONDS                      = 0x00000001, // data is seconds         
    USECONDS                     = 0x00000002, // data is microseconds    
    NSECONDS                     = 0x00000004, // data is nanoseconds     
    ABSOLUTE                     = 0x00000008, // absolute timeout        
    LEEWAY                       = 0x00000010, // ext[1] holds leeway for power aware timers 
    CRITICAL                     = 0x00000020, // system does minimal timer coalescing 
    BACKGROUND                   = 0x00000040, // system does maximum timer coalescing 
    MACH_CONTINUOUS_TIME         = 0x00000080, //
    MACHTIME                     = 0x00000100, // data is mach absolute time units 
}
