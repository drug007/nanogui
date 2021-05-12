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
    float total_shift = 0, shift;
    Location loc;

    this(float v) { loc = Location(v); }
    
    bool _complete;
    bool complete() { return _complete; }
    void next(int v)
    {
        if (total_shift + v > shift)
            _complete = true;
        else
        {
            total_shift += v;
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
    assert(a.total_shift == 128);
    assert(a.total_shift == sum(seq));
    assert(log == [0, 10, 31, 43, 56, 80, 95, 111, 128]);

    a = Automata(0);
    a.shift = 40;
    test(a, seq);
    assert(a.shift == 40);
    assert(a.total_shift == 31);
    assert(a.total_shift == sum(seq[0..2]));

    // next total_shift is equal to start of an element
    a = Automata(0);
    a.shift = 43;
    test(a, seq);
    assert(a.total_shift == 43);
    assert(a.shift == 43);

    a = Automata(0);
    a.shift = 58;
    test(a, seq);
    assert(a.total_shift == 56);
    assert(a.shift == 58);

    a = Automata(0);
    test(a, seq.retro);
    assert(a.total_shift == 128);

    a = Automata(0);
    a.shift = 83;
    test(a, seq.retro);
    assert(a.total_shift == 72);
    assert(a.shift == 83);
    
    a = Automata(0);
    a.shift = 85;
    test(a, seq.retro);
    assert(a.total_shift == 85);
    assert(a.shift == 85);

    // 80 70  49  37  24   0
    //   [10, 21, 12, 13, 24]
    auto subseq = seq[0..5];

    a = Automata(0);
    a.shift = 85;
    test(a, seq[0..5].retro);
    assert(a.total_shift == 80);
    assert(a.shift == 85);

    a = Automata(0);
    a.shift = 38;
    test(a, seq[0..5].retro);
    assert(a.total_shift == 37);
    assert(a.shift == 38);
}