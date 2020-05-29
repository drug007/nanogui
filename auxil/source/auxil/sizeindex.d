module aux.sizeindex;

import std.range : isRandomAccessRange;

struct SizeWindow
{
	/// lower boundary of the requested window in size units
	double start;
	/// length of the requested window in size units
	double length;
}

struct IndexWindow
{
	/// lower boundary of the result window in index units
	size_t start;
	/// length of the result window in index units
	size_t length;
	/// lower boundary of the result window in size units
	double current;
}

/// Given a range of items having size convert given indices to the 
/// cumulative size of all elements from the first one to elements with
/// given indices
///
/// data given range those elements have some size
/// spacing is additional size for spacing between range elements
/// start index is the index of the first range element whose size we want to get
/// last index is the index of the last given range element whose size we want to get
/// start, finish are sizes of first and last elements
SizeWindow indexToSize(R)(R data, auto ref const(IndexWindow) iw)
	if (isRandomAccessRange!R)
{
	// current summary size
	double curr = 0;
	// the index of the current range element
	size_t idx;
	size_t last_index = iw.start + iw.length;
	// initial values of resulting sizes
	double start_size = 0;

	// find for the summary size of the first given range element
	foreach(ref const e; data)
	{
		if (idx >= iw.start)
		{
			start_size = curr;
			idx++;
			curr += e;
			break;
		}
		idx++;
		curr += e;
	}

	// start index is beyond range
	// set result size equal to total summary size
	if (iw.start >= data.length)
	{
		return SizeWindow(curr, 0);
	}

	double last_size = 0;
	// find the size of the last element
	const low_boundary = idx;
	foreach(ref const e; data[low_boundary..$])
	{
		if (idx >= last_index)
		{
			last_size = curr;
			break;
		}
		idx++;
		curr += e;
	}

	// if only the last index is beyond the given range
	// then only the weight of the last element is equal
	// to summary weight
	if (last_index >= data.length)
		last_size = curr;

	return SizeWindow(start_size, last_size - start_size);
}

/// Given range of elements having size convert `data` convert window in size units `sw`
/// to the result window in index units using current window in index units `iw`
///
/// data the range of elements having size
/// sw the requested window in size units
/// iw the current window in index units
///
/// returns the result window in index units
auto sizeToIndex(R)(R data, auto ref const(SizeWindow) sw, auto ref const(IndexWindow) iw)
	if (isRandomAccessRange!R)
{
	IndexWindow index;
	index.start = iw.start;

	size_t idx = iw.start;
	double current_size = iw.current;

	assert(sw.length >= 0);

	// current weight is greater than start weight so
	// iterate over the range backward
	if (current_size > sw.start)
	{
		assert(0 <= idx && idx < data.length);
		for(; idx > 0; idx--)
		{
			// check if the current element has size lesser than
			// start size but the next element has size greater than
			// start size
			if (current_size - data[idx-1] <= sw.start &&
				current_size > sw.start)
			{
				index.start = idx-1;
				current_size -= data[idx-1];
				break;
			}
			else
			{
				current_size -= data[idx-1];
			}
		}
	}
	else
	{
		// current weight is equal to or lesser than start weight so
		// iterate over the range forward
		idx = index.start;
		for(; idx < data.length; idx++)
		{
			// check if the current element has cumulative size lesser than
			// start weight and the next element has cumulative size larger
			// than start weight
			if (current_size <= sw.start && current_size + data[idx] > sw.start)
			{
				index.start = idx;
				break;
			}
			else
			{
				current_size += data[idx];
			}
		}
		assert(idx <= data.length);
		assert(
			(current_size <= sw.start && idx == data.length) ||
			(current_size <= sw.start && (current_size + data[idx]) > sw.start) || 
			(idx == data.length /*&& e0 == E*/)
		);
	}

	// if current index is out of give range
	// set start index equal to the last element
	// and length equals to zero, current size is equal
	// to total size of the range
	if (idx == data.length)
	{
		// start (and finish too) is beyond the last index

		index.start = data.length;
		index.length = 0;
		index.current = current_size;
		return index;
	}

	// we have found the first element and its
	// position both in size and index units 
	index.current = current_size;

	// looking for the last element

	// go to next element
	current_size += data[idx];
	idx++;

	// find index of the element which cumulative size
	// equals to or larger than high boundary in size units
	for(; idx < data.length; idx++)
	{
		if (current_size >= sw.start + sw.length)
		{
			break;
		}
		else
			current_size += data[idx];
	}

	index.length = idx - index.start;
	return index;
}

private
{
	struct Record
	{
		ubyte[]     data;
		SizeWindow  size_window;
		IndexWindow input_idx, index_window;
	}

	enum ubyte[] data = [30, 40, 50, 20];

	import std.algorithm : sum;
	const double total_size = sum(data); // total size of all elements

	auto sizeToIndexData = [
		//                     start size                      start index                    start index
		//                        ||        length             || length                       ||           length
		//                        \/           ||              || || current size              ||           || current size
		// window length is zero               \/              \/ \/ \/                        \/           \/           \/
		Record(data, SizeWindow(   0,           0), IndexWindow(0, 0, 0), IndexWindow(          0,           1,          0)),
		// window length equals to first element size minus one
		Record(data, SizeWindow(   0, data[0] - 1), IndexWindow(0, 0, 0), IndexWindow(          0,           1,          0)),
		// window length equals to first element size
		Record(data, SizeWindow(   0,     data[0]), IndexWindow(0, 0, 0), IndexWindow(          0,           1,          0)),
		// window length is larger than first element size
		// (but less than size of two first elements)
		Record(data, SizeWindow(   0, data[0] + 1), IndexWindow(0, 0, 0), IndexWindow(          0,           2,          0)),
		// window length is larger than total size of the range
		Record(data, SizeWindow(   0,        1e18), IndexWindow(0, 0, 0), IndexWindow(          0, data.length,          0)),
		// new size is larger than total size of the range
		Record(data, SizeWindow(1e18,          10), IndexWindow(0, 0, 0), IndexWindow(data.length,           0, total_size)),
		// new size is larger than total size of the range
		Record(data, SizeWindow(1e18,        1e18), IndexWindow(0, 0, 0), IndexWindow(data.length,           0, total_size)),

		// Record(data, SizeWindow(   0,     data[2]), IndexWindow(2, 0,  70), IndexWindow(          2,           1,          0)),
		// Record(data, SizeWindow(   0,     data[2]), IndexWindow(3, 0, 120), IndexWindow(          2,           1,          0)),
	];

	auto indexToSizeData = [
		//                     start size                      start index                    start index
		//                        ||        length             || length                       ||           length
		//                        \/           ||              || || current size              ||           || current size
		// window length is zero               \/              \/ \/ \/                        \/           \/           \/
		Record(data, SizeWindow(   0,     data[0]), IndexWindow(0, 0, 0), IndexWindow(          0,           1,          0)),
		Record(data, SizeWindow(   0,  total_size), IndexWindow(0, 0, 0), IndexWindow(          0, data.length,          0)),
		Record(data, SizeWindow(  70,     data[2]), IndexWindow(0, 0, 0), IndexWindow(          2,           1,          0)),
		Record(data, SizeWindow(total_size,     0), IndexWindow(0, 0, 0), IndexWindow(data.length,          10,          0)),
	];
}

version(unittest)
{
	@(0, 1, 2, 3, 4, 5, 6)
	void testSizeToIndex(int id)
	{
		import unit_threaded;

		with(sizeToIndexData[id])
		{
			auto index = sizeToIndex(data, size_window, input_idx);

			index.start  .should.be == index_window.start;
			index.length .should.be == index_window.length;
			index.current.should.be  ~ index_window.current;
		}
	}

	@(0, 1, 2, 3)
	void testIndexToSize(int id)
	{
		import unit_threaded;

		with(indexToSizeData[id])
		{
			auto size = indexToSize(data, index_window);

			size.start  .should.be == size_window.start;
			size.length .should.be == size_window.length;
		}
	}
}
