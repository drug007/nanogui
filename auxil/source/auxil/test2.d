module auxil.test2;

import std;

//     128 118  97  85  72  48  33  17    0
//           0  10  31  43  56  80  95  111 128
auto seq = [10, 21, 12, 13, 24, 15, 16, 17];

struct Location
{
    float loc;
    void next(float v)
    {
        loc += v;
    }
    @disable this();
    this(float v) { loc = v; }
}

struct Automata
{
    // sum of all previous elements
    // it can have only fixed set of values so it is called `fixed`
    float fixedValue = 0;
    // the value we should iterate over given sequence and
    // can be any value
    float destinationShift;
    Location loc;
    float init_value;

    this(float v) { loc = Location(v); init_value = v; }
    
    private bool _complete;
    bool complete() { return _complete; }
    void next(int v)
    {
        if (fixedValue + v > destinationShift)
        {
            _complete = true;
        }
        else
        {
            fixedValue += v;
            loc.next(v);
        }
    }

    auto position(bool forward)()
    {
        static if (forward)
            return init_value + fixedValue;
        else
            return init_value - fixedValue;
    }
}

auto test(R)(ref Automata a, R data)
{
    float[] log;
    test(a, data, log);
}

auto test(bool forward, R)(ref Automata a, R r, ref float[] log)
{
    log ~= a.loc.loc;
    static if (forward)
        auto data = r;
    else
        auto data = r.retro;
    foreach(e; data)
    {
        a.next(e);
        if (a.complete)
            break;
        log ~= a.loc.loc;
    }
}

void testAutomata()
{
    float[] posLog;
    auto a = Automata(0);
    test!true(a, seq, posLog);
    assert(a.fixedValue == 128);
    assert(a.fixedValue == sum(seq));
    assert(posLog == [0, 10, 31, 43, 56, 80, 95, 111, 128]);

    posLog = null;
    a = Automata(0);
    a.destinationShift = 40;
    test!true(a, seq, posLog);
    assert(a.destinationShift == 40);
    assert(a.fixedValue == 31);
    assert(a.fixedValue == sum(seq[0..2]));
    assert(posLog == [0, 10, 31]);

    // next fixedValue is equal to start of an element
    posLog = null;
    a = Automata(0);
    a.destinationShift = 43;
    test!true(a, seq, posLog);
    assert(a.fixedValue == 43);
    assert(a.destinationShift == 43);
    assert(posLog == [0, 10, 31, 43]);

    posLog = null;
    a = Automata(0);
    a.destinationShift = 58;
    test!true(a, seq, posLog);
    assert(a.fixedValue == 56);
    assert(a.destinationShift == 58);
    assert(posLog == [0, 10, 31, 43, 56]);

    posLog = null;
    a = Automata(0);
    a.init_value = 128;
    test!false(a, seq, posLog);
    assert(a.fixedValue == 128);
    const total_sum = sum(seq);
    assert(posLog.equal([0, 17, 33, 48, 72, 85, 97, 118, 128]));
    assert(posLog.map!(a=>total_sum-a).equal([0, 10, 31, 43, 56, 80, 95, 111, 128].retro));

    posLog = null;
    a = Automata(0);
    a.destinationShift = 83;
    test!false(a, seq, posLog);
    assert(a.fixedValue == 72);
    assert(a.destinationShift == 83);
    assert(posLog.equal([0, 17, 33, 48, 72]));
    
    posLog = null;
    a = Automata(0);
    a.destinationShift = 85;
    test!false(a, seq, posLog);
    assert(a.fixedValue == 85);
    assert(a.destinationShift == 85);
    assert(posLog.equal([0, 17, 33, 48, 72, 85]));

    // 80 70  49  37  24   0
    //   [10, 21, 12, 13, 24]
    auto subseq = seq[0..5];

    posLog = null;
    a = Automata(0);
    a.destinationShift = 85;
    test!false(a, seq[0..5], posLog);
    assert(a.fixedValue == 80);
    assert(a.destinationShift == 85);
    assert(posLog.equal([0, 24, 37, 49, 70, 80]));

    posLog = null;
    a = Automata(0);
    a.destinationShift = 38;
    test!false(a, seq[0..5], posLog);
    assert(a.fixedValue == 37);
    assert(a.destinationShift == 38);
    assert(posLog.equal([0, 24, 37]));
}