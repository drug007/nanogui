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

    this(float v) { loc = Location(v); }
    
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
}

auto test(R)(ref Automata a, R data)
{
    float[] log;
    test(a, data, log);
}

auto test(R)(ref Automata a, R data, ref float[] log)
{
    log ~= a.loc.loc;
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
    float[] log;
    auto a = Automata(0);
    test(a, seq, log);
    assert(a.fixedValue == 128);
    assert(a.fixedValue == sum(seq));
    assert(log == [0, 10, 31, 43, 56, 80, 95, 111, 128]);

    log = null;
    a = Automata(0);
    a.destinationShift = 40;
    test(a, seq, log);
    assert(a.destinationShift == 40);
    assert(a.fixedValue == 31);
    assert(a.fixedValue == sum(seq[0..2]));
    assert(log == [0, 10, 31]);

    // next fixedValue is equal to start of an element
    log = null;
    a = Automata(0);
    a.destinationShift = 43;
    test(a, seq, log);
    assert(a.fixedValue == 43);
    assert(a.destinationShift == 43);
    assert(log == [0, 10, 31, 43]);

    log = null;
    a = Automata(0);
    a.destinationShift = 58;
    test(a, seq, log);
    assert(a.fixedValue == 56);
    assert(a.destinationShift == 58);
    assert(log == [0, 10, 31, 43, 56]);

    log = null;
    a = Automata(0);
    test(a, seq.retro, log);
    assert(a.fixedValue == 128);
    const total_sum = sum(seq);
    assert(log.equal([0, 17, 33, 48, 72, 85, 97, 118, 128]));
    assert(log.map!(a=>total_sum-a).equal([0, 10, 31, 43, 56, 80, 95, 111, 128].retro));

    log = null;
    a = Automata(0);
    a.destinationShift = 83;
    test(a, seq.retro, log);
    assert(a.fixedValue == 72);
    assert(a.destinationShift == 83);
    assert(log.equal([0, 17, 33, 48, 72]));
    
    log = null;
    a = Automata(0);
    a.destinationShift = 85;
    test(a, seq.retro, log);
    assert(a.fixedValue == 85);
    assert(a.destinationShift == 85);
    assert(log.equal([0, 17, 33, 48, 72, 85]));

    // 80 70  49  37  24   0
    //   [10, 21, 12, 13, 24]
    auto subseq = seq[0..5];

    log = null;
    a = Automata(0);
    a.destinationShift = 85;
    test(a, seq[0..5].retro, log);
    assert(a.fixedValue == 80);
    assert(a.destinationShift == 85);
    assert(log.equal([0, 24, 37, 49, 70, 80]));

    log = null;
    a = Automata(0);
    a.destinationShift = 38;
    test(a, seq[0..5].retro, log);
    assert(a.fixedValue == 37);
    assert(a.destinationShift == 38);
    assert(log.equal([0, 24, 37]));
}