/**
* Contains the garbage collector configuration.
*
* Copyright: Copyright Digital Mars 2014
* License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
*/

module gc.config;

import core.stdc.stdio;
import core.internal.parseoptions;

struct Config
{
    bool disable;            // start disabled
    ubyte profile;           // enable profiling with summary when terminating program
    bool precise;            // enable precise scanning
    bool concurrent;         // enable concurrent collection

    size_t initReserve;      // initial reserve (MB)
    size_t minPoolSize = 1;  // initial and minimum pool size (MB)
    size_t maxPoolSize = 64; // maximum pool size (MB)
    size_t incPoolSize = 3;  // pool size increment (MB)
    float heapSizeFactor = 2.0; // heap size to used memory ratio

@nogc nothrow:

    bool initialize()
    {
        return initConfigOptions(this, "gcopt");
    }

    void help() @nogc nothrow
    {
        string s = "GC options are specified as white space separated assignments:
    disable:0|1    - start disabled (%d)
    profile:0|1|2  - enable profiling with summary when terminating program (%d)
    precise:0|1    - enable precise scanning (not implemented yet)
    concurrent:0|1 - enable concurrent collection (not implemented yet)

    initReserve:N  - initial memory to reserve in MB (%lld)
    minPoolSize:N  - initial and minimum pool size in MB (%lld)
    maxPoolSize:N  - maximum pool size in MB (%lld)
    incPoolSize:N  - pool size increment MB (%lld)
    heapSizeFactor:N - targeted heap size to used memory ratio (%g)
";
        printf(s.ptr, disable, profile, cast(long)initReserve, cast(long)minPoolSize,
               cast(long)maxPoolSize, cast(long)incPoolSize, heapSizeFactor);
    }

    string errorName() @nogc nothrow { return "GC"; }
}
