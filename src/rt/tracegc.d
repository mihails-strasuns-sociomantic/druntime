/**
 * Contains implementations of functions called when the
 *   -profile=gc
 * switch is thrown.
 *
 * Copyright: Copyright Digital Mars 2015 - 2015.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Walter Bright
 * Source: $(DRUNTIMESRC src/rt/_tracegc.d)
 */

module rt.tracegc;

// version = tracegc;

version (none)
{
    // this exercises each function

    struct S { ~this() { } }
    class C { }
    interface I { }

    void main()
    {
      {
        auto a = new C();
        auto b = new int;
        auto c = new int[3];
        auto d = new int[][](3,4);
        auto e = new float;
        auto f = new float[3];
        auto g = new float[][](3,4);
      }
        printf("\n");
      {
        int[] a; delete a;
        S[] as; delete as;
        C c; delete c;
        I i; delete i;
        C* pc = &c; delete *pc;
        I* pi = &i; delete *pi;
        int* pint; delete pint;
        S* ps; delete ps;
      }
        printf("\n");
      {
        int[] a = [1, 2, 3];
        string[int] aa = [1:"one", 2:"two", 3:"three"];
      }
        printf("\n");
      {
        int[] a, b, c;
        c = a ~ b;
        c = a ~ b ~ c;
      }
        printf("\n");
      {
        dchar dc = 'a';
        char[] ac; ac ~= dc;
        wchar[] aw; aw ~= dc;
        char[] ac2; ac2 ~= ac;
        int[] ai; ai ~= 3;
      }
        printf("\n");
      {
        int[] ai; ai.length = 10;
        float[] af; af.length = 10;
      }
        printf("\n");
        int v;
      {
        int foo() { return v; }
        static int delegate() dg;
        dg = &foo;      // dynamic closure
      }
    }
}

extern (C) Object _d_newclass(const ClassInfo ci);
extern (C) void[] _d_newarrayT(const TypeInfo ti, size_t length);
extern (C) void[] _d_newarrayiT(const TypeInfo ti, size_t length);
extern (C) void[] _d_newarraymTX(const TypeInfo ti, size_t[] dims);
extern (C) void[] _d_newarraymiTX(const TypeInfo ti, size_t[] dims);
extern (C) void* _d_newitemT(in TypeInfo ti);
extern (C) void* _d_newitemiT(in TypeInfo ti);
extern (C) void _d_callfinalizer(void* p);
extern (C) void _d_callinterfacefinalizer(void *p);
extern (C) void _d_delclass(Object* p);
extern (C) void _d_delinterface(void** p);
extern (C) void _d_delstruct(void** p, TypeInfo_Struct inf);
extern (C) void _d_delarray_t(void[]* p, const TypeInfo_Struct _);
extern (C) void _d_delmemory(void* *p);
extern (C) byte[] _d_arraycatT(const TypeInfo ti, byte[] x, byte[] y);
extern (C) void[] _d_arraycatnTX(const TypeInfo ti, byte[][] arrs);
extern (C) void* _d_arrayliteralTX(const TypeInfo ti, size_t length);
extern (C) void* _d_assocarrayliteralTX(const TypeInfo_AssociativeArray ti,
    void[] keys, void[] vals);
extern (C) void[] _d_arrayappendT(const TypeInfo ti, ref byte[] x, byte[] y);
extern (C) byte[] _d_arrayappendcTX(const TypeInfo ti, ref byte[] px, size_t n);
extern (C) void[] _d_arrayappendcd(ref byte[] x, dchar c);
extern (C) void[] _d_arrayappendwd(ref byte[] x, dchar c);
extern (C) void[] _d_arraysetlengthT(const TypeInfo ti, size_t newlength, void[]* p);
extern (C) void[] _d_arraysetlengthiT(const TypeInfo ti, size_t newlength, void[]* p);
extern (C) void* _d_allocmemory(size_t sz);



extern extern(C) void gc_resetLastAllocation();

// Used as wrapper function body to get actual stats. Calling `original_func()`
// will call wrapped function with all required arguments.
//
// Placed here as a separate string constant to simplify maintenance as it is
// much more likely to be modified than rest of generation code.
enum accumulator = q{
    import rt.profilegc : accumulate;
    import core.memory : GC;

    static if (is(typeof(ci)))
        string name = ci.name;
    else static if (is(typeof(ti)))
        string name = ti.toString();
    else static if (__FUNCTION__ == "rt.tracegc._d_arrayappendcdTrace")
        string name = "char[]";
    else static if (__FUNCTION__ == "rt.tracegc._d_arrayappendwdTrace")
        string name = "wchar[]";
    else static if (__FUNCTION__ == "rt.tracegc._d_allocmemoryTrace")
        string name = "closure";
    else
        string name = "";

    version(tracegc)
    {
        import core.stdc.stdio;

        printf("%s file = '%.*s' line = %d function = '%.*s' type = %.*s\n",
            __FUNCTION__.ptr,
            file.length, file.ptr,
            line,
            funcname.length, funcname.ptr,
            name.length, name.ptr
        );
    }
    gc_resetLastAllocation();

    scope(exit)
    {
        auto stats = GC.stats();
        if (stats.lastAllocSize > 0)
            accumulate(file, line, funcname, name, stats.lastAllocSize);
    }

    return original_func();
};

mixin(generateTraceWrappers());
//pragma(msg, generateTraceWrappers());

////////////////////////////////////////////////////////////////////////////////
// code gen implementation

private string generateTraceWrappers()
{
    string code;

    foreach (name; __traits(allMembers, mixin(__MODULE__)))
    {
        static if (name.length > 3 && name[0..3] == "_d_")
        {
            mixin("alias Declaration = " ~ name ~ ";");
            code ~= generateWrapper!Declaration();
        }
    }

    return code;
}

private string generateWrapper(alias Declaration)()
{
    static size_t findParamIndex(string s)
    {
        assert (s[$-1] == ')');
        size_t brackets = 1;
        while (brackets != 0)
        {
            s = s[0 .. $-1];
            if (s[$-1] == ')')
                ++brackets;
            if (s[$-1] == '(')
                --brackets;
        }

        assert(s.length > 1);
        return s.length - 1;
    }

    auto type_string = typeof(Declaration).stringof;
    auto name = __traits(identifier, Declaration);
    auto param_idx = findParamIndex(type_string);

    auto new_declaration = type_string[0 .. param_idx] ~ " " ~ name
        ~ "Trace(string file, int line, string funcname, "
        ~ type_string[param_idx+1 .. $];
    auto call_original = "    scope original_func = { return "
        ~ __traits(identifier, Declaration) ~ "(" ~ Arguments!Declaration() ~ "); };";

    return new_declaration ~ "\n{\n" ~
           call_original ~ "\n" ~
           accumulator ~ "\n" ~
           "}\n";
}

string Arguments(alias Func)()
{
    string result = "";

    static if (is(typeof(Func) PT == __parameters))
    {
        foreach (idx, _; PT)
            result ~= __traits(identifier, PT[idx .. idx + 1]) ~ ", ";
    }

    return result;
}

unittest
{
    void foo(int x, double y) { }
    static assert (Arguments!foo == "x, y, ");
}
