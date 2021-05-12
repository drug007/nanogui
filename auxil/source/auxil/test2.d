module auxil.test2;

import std;

//     128 118  97  85  72  48  33  17    0
//           0  10  31  43  56  80  95  111 128
auto seq = [10, 21, 12, 13, 24, 15, 16, 17];

struct Automata
{
    float total_shift = 0, shift;
    
    bool _complete;
    bool complete() { return _complete; }
    void next(int v)
    {
        if (total_shift + v > shift)
            _complete = true;
        else
            total_shift += v;
    }
}

auto test(R)(ref Automata a, R data)
{
    foreach(e; data)
    {
        a.next(e);
        if (a.complete)
            break;
    }
}

void testAutomata()
{
    Automata a;
    test(a, seq);
    assert(a.total_shift == 128);
    assert(a.total_shift == sum(seq));

    a = Automata();
    a.shift = 40;
    test(a, seq);
    assert(a.total_shift == sum(seq[0..2]));

    // next total_shift is equal to start of an element
    a = Automata();
    a.shift = 43;
    test(a, seq);
    assert(a.total_shift == 43);
    assert(a.shift == 43);

    a = Automata();
    a.shift = 58;
    test(a, seq);
    assert(a.total_shift == 56);
    assert(a.shift == 58);

    a = Automata();
    test(a, seq.retro);
    assert(a.total_shift == 128);

    a = Automata();
    a.shift = 83;
    test(a, seq.retro);
    assert(a.total_shift == 72);
    assert(a.shift == 83);
    
    a = Automata();
    a.shift = 85;
    test(a, seq.retro);
    assert(a.total_shift == 85);
    assert(a.shift == 85);

    // 80 70  49  37  24   0
    //   [10, 21, 12, 13, 24]
    auto subseq = seq[0..5];

    a = Automata();
    a.shift = 85;
    test(a, seq[0..5].retro);
    assert(a.total_shift == 80);
    assert(a.shift == 85);

    a = Automata();
    a.shift = 38;
    test(a, seq[0..5].retro);
    assert(a.total_shift == 37);
    assert(a.shift == 38);
}