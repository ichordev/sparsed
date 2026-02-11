/**
Copyright: Copyright 2024–2026 Aya Partridge
License: Distributed under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version. See the accompanying `COPYING.LESSER.md` file or go to <https://www.gnu.org/licenses/> for more details.
*/
module sparse;

import memterface.allocator.gc, memterface.iface;

///The smallest integer that can fully index a static sparse array with `sparseSize``.
template StaticSparseSetIndex(uint sparseSize){
	static if(sparseSize <= ubyte.max+1){
		alias StaticSparseSetIndex = ubyte;
	}else static if(sparseSize <= ushort.max+1){
		alias StaticSparseSetIndex = ushort;
	}else{
		alias StaticSparseSetIndex = uint;
	}
}

template SparseSetElement(Index, Value)
if(is(Index == uint) || is(Index == ushort) || is(Index == ubyte)){
	alias SparseSetElement = SparseSetElementImpl!(const Index, Value);
}

private struct SparseSetElementImpl(Index, Value){
	Index index;
	static if(!is(Value == void)){
		Value value;
	}
}

/**
A classic sparse set using static arrays.
Can optionally store an arbitrary type in order to act as a map.
Params:
	sparseSize_ = The number of indices in the sparse array. (i.e. the max set index + 1)
	denseSize_ = How many elements can be stored in the set at a time.
	Value_ = What value to store with the items in the dense array. `void` for none.
*/
struct StaticSparseSet(uint sparseSize_, uint denseSize_=sparseSize_, Value_=void){
	enum sparseSize = sparseSize_;
	enum denseSize = denseSize_;
	static assert(sparseSize > 0, "`sparseSize` must be greater than 0");
	static assert(denseSize  > 0,  "`denseSize` must be greater than 0");
	static assert(denseSize <= sparseSize, "Unnecessarily large `denseSize`. Should be at most equal to `sparseSize`");
	alias Index = StaticSparseSetIndex!sparseSize;
	alias Value = Value_;
	alias Element = SparseSetElement!(Index, Value);
	
	private{
		alias ElementImpl = SparseSetElementImpl!(Index, Value);
		//A list of indices into `dense`.
		Index[sparseSize] sparse;
		//The number of elements currently stored in `dense`. Can be read safely with `length`.
		uint elementCount = 0;
		//A list of indices into `sparse`, each with an optional `Value`.
		ElementImpl[denseSize] dense;
	}
	
	///The number of elements in the set.
	@property uint length() const nothrow @nogc pure @safe =>
		elementCount;
	
	///How many more elements can be added to the set before we run out of space.
	@property uint capacityLeft() const nothrow @nogc pure @safe =>
		cast(uint)dense.length - elementCount;
	
	static if(!is(Value == void)){
		///Gets a slice containing the elements in the set.
		ElementImpl[] getElements() return nothrow @nogc pure @safe =>
			cast(ElementImpl[])dense[0..elementCount];
	}
	///Gets a read-only slice containing the elements in the set.
	const(ElementImpl)[] readElements() return const nothrow @nogc pure @safe =>
		cast(const(ElementImpl)[])dense[0..elementCount];
	
	/**
	Clears the set.
	Note: Should not be called when iterating over the result of `getElements`/`readElements`.
	*/
	void clear() nothrow @nogc pure @safe{
		elementCount = 0;
	}
	
	/**
	Removes element `ind` from the set. `ind` must be in the set.
	Note: Should not be called when iterating over the result of `getElements`/`readElements`.
	*/
	void remove(Index ind)
	in(this.has(ind)){
		dense[sparse[ind]] = dense[elementCount-1];
		static if(!is(Value == void)){
			dense[elementCount-1].value = Value.init;
		}
		sparse[dense[elementCount-1].index] = sparse[ind];
		elementCount--;
	}
	/**
	Tries to remove element `ind` from the set.
	Note: Should not be called when iterating over the result of `getElements`/`readElements`.
	Returns: `false` if the element didn't exist.
	*/
	bool tryRemove(Index ind){
		if(this.has(ind)){
			dense[sparse[ind]] = dense[elementCount-1];
			static if(!is(Value == void)){
				dense[elementCount-1].value = Value.init;
			}
			sparse[dense[elementCount-1].index] = sparse[ind];
			elementCount--;
			return true;
		}else return false;
	}
	
	///Check whether element `ind` is in the set.
	bool has(Index ind) const nothrow @nogc pure @safe =>
		ind < sparse.length && sparse[ind] < elementCount && dense[sparse[ind]].index == ind;
	
	static if(is(Value == void)){
		///Return whether `ind` is in the set or not.
		bool opBinaryRight(string op: "in")(Index ind) const nothrow @nogc pure @safe =>
			this.has(ind);
		
		/**
		Add element `ind` to the set.
		Returns: `false` if there's no space left, or element `ind` already existed.
		*/
		bool add(Index ind) nothrow @nogc pure @safe
		in(ind < sparse.length){
			if(elementCount < dense.length && !this.has(ind)){
				sparse[ind] = cast(Index)elementCount;
				dense[elementCount] = ElementImpl(ind);
				elementCount++;
				return true;
			}else return false;
		}
	}else{
		///Check if `ind` is in the set, and get a pointer to its associated value if so.
		inout(Value)* opBinaryRight(string op: "in")(Index ind) return inout nothrow @nogc pure @safe{
			if(this.has(ind)){
				return &dense[sparse[ind]].value;
			}
			return null;
		}
		
		/**
		Add element `ind` with associated `value` to the set.
		Returns: `false` if there's no space left, or element `ind` already existed.
		*/
		bool add()(Index ind, auto ref Value value)
		in(ind < sparse.length){
			if(elementCount < dense.length && !this.has(ind)){
				sparse[ind] = cast(Index)elementCount;
				dense[elementCount] = ElementImpl(ind, value);
				elementCount++;
				return true;
			}else return false;
		}
		
		///Get a pointer to the value of `ind`, which is assumed to be in the set.
		Value* get(Index ind) return nothrow @nogc pure @system
		in(this.has(ind)) =>
			&dense[sparse[ind]].value;
		/**
		Try to get a pointer to the value of `ind`.
		Returns: `null` if `ind` is not in the set.
		*/
		Value* tryGet(Index ind) return nothrow @nogc pure @safe =>
			this.has(ind) ? &dense[sparse[ind]].value : null;
		
		///Get a const pointer to the value of `ind`, which is assumed to be in the set.
		const(Value)* read(Index ind) return const nothrow @nogc pure @system
		in(this.has(ind)) =>
			&dense[sparse[ind]].value;
		/**
		Try to get a const pointer to the value of `ind`.
		Returns: `null` if `ind` is not in the set.
		*/
		const(Value)* tryRead(Index ind) return const nothrow @nogc pure @safe =>
			this.has(ind) ? &dense[sparse[ind]].value : null;
	}
}
unittest{
	alias SS = StaticSparseSet!(40, 20);
	alias SSE = SS.Element;
	SS set;
	set.add(0);
	set.add(2);
	set.add(4);
	set.add(5);
	set.remove(0);
	set.add(6);
	assert(set.length == 4);
	assert(set.readElements() == [SSE(5), SSE(2), SSE(4), SSE(6)]);
	assert( set.has(5));
	assert(!set.has(0));
	assert(4 in set);
	assert(7 !in set);
	foreach(element; set.readElements()){
		set.add(cast(SS.Index)(element.index+1));
	}
	assert(set.length == 6);
	assert(set.readElements() == [SSE(5), SSE(2), SSE(4), SSE(6), SSE(3), SSE(7)]);
	set.clear();
	assert(set.length == 0);
	assert(set.readElements() == []);
}
unittest{
	alias SS = StaticSparseSet!(40, 20, string);
	alias SSE = SS.Element;
	SS set;
	set.add(0, "Testing");
	set.add(2, "Hello");
	set.add(4, "World");
	set.add(5, ":)");
	set.remove(0);
	set.add(6, ":O");
	assert(set.getElements() == [SSE(5, ":)"), SSE(2, "Hello"), SSE(4, "World"), SSE(6, ":O")]);
	assert( set.has(5));
	assert(!set.has(0));
	assert(4 in set);
	assert(7 !in set);
	assert(*(4 in set) == "World");
	assert(*set.read(4) == "World");
	*set.get(4) = "Dlrow";
	assert(*(4 in set) == "Dlrow");
}

/**
A resizeable classic sparse set using dynamically allocated arrays.
Can optionally store an arbitrary type in order to act as a map.
Unless using `GCAllocator`, when an instance is no longer in-use its data must be freed with `.dispose()` to avoid memory leaks.
Params:
	Index_ = The type to use for indices in the sparse and dense arrays. Must be `ubyte`, `ushort`, or `uint`.
	Value_ = What value to store with the items in the dense array. `void` for none.
	Allocator_ = What type of allocator is used to allocate the dense array.
*/
struct SparseSet(Index_=uint, Value_=void, Allocator_=GCAllocator)
if((is(Index_ == uint) || is(Index_ == ushort) || is(Index_ == ubyte)) && isAllocator!Allocator_){
	alias Index = Index_;
	alias Value = Value_;
	alias Allocator = Allocator_;
	alias Element = SparseSetElement!(Index, Value);
	
	///How many extra elements to allocate at once when the dense array needs to grow.
	Index growAmount = 16;
	private{
		alias ElementImpl = SparseSetElementImpl!(Index, Value);
		Index _shrinkThreshold = 48;
		//a list of indices into `dense`
		ubyte[] _sparse;
		//the number of elements currently stored in `dense`. Can be read safely with `length`
		Index elementCount = 0;
		//a list of indices into `sparse`, each with an optional `Value`
		static if(is(Value == void)){
			ubyte[] _dense;
		}else{
			void[] _dense;
		}
		pragma(inline,true){
			@property inout(Index)[] sparse() inout nothrow @nogc pure @trusted =>
				(*cast(inout(Index)[]*)&_sparse)[0..$/Index.sizeof];
			@property sparse(Index[] val) nothrow @nogc pure @trusted =>
				_sparse = cast(typeof(_sparse))val;
			
			@property inout(ElementImpl)[] dense() inout nothrow @nogc pure @trusted =>
				(*cast(inout(ElementImpl)[]*)&_dense)[0..$/ElementImpl.sizeof];
			@property dense(ElementImpl[] val) nothrow @nogc pure @trusted =>
				_dense = cast(typeof(_dense))val;
		}
	}
	Allocator allocator;
	
	import memterface.ctor;
	
	/**
	Params:
		allocator = The allocator that will be used to allocate the sparse and dense arrays.
		sparseSize = The number of indices in the sparse array. (i.e. the max set index + 1)
	*/
	this()(auto ref Allocator allocator, uint sparseSize, Index growAmount=16, Index shrinkThreshold=48){
		this.allocator = allocator;
		this.growAmount = growAmount;
		this._shrinkThreshold = shrinkThreshold;
		assert(sparseSize > 0 && sparseSize <= Index.max+1L, "`sparseSize` must be in the range of [0, Index.max+1]");
		this.sparse = this.allocator.newArray!Index(sparseSize);
	}
	
	///The number of elements in the set.
	@property Index length() const nothrow @nogc pure @safe =>
		elementCount;
	
	///How many more elements can be added to the set before we run out of space.
	@property uint capacityLeft() const nothrow @nogc pure @safe =>
		cast(uint)sparse.length - elementCount;
	
	static if(!is(Value == void)){
		///Gets a slice containing the elements in the set.
		ElementImpl[] getElements() return nothrow @nogc pure @safe =>
			cast(ElementImpl[])dense[0..elementCount];
	}
	///Gets a read-only slice containing the elements in the set.
	const(ElementImpl)[] readElements() return const nothrow @nogc pure @safe =>
		cast(const(ElementImpl)[])(dense[0..elementCount]);
	
	///Duplicates the set and returns a new set allocated with `allocator`.
	SparseSet!(Index, Value, A) dup(A=Allocator)(auto ref A allocator){
		auto sparse = this.sparse;
		auto ret = SparseSet!(Value, indices, A)(allocator, sparse.length, growAmount, shrinkThreshold);
		ret.sparse[] = sparse[];
		ret.elementCount = elementCount;
		ret.denseSize = dense.length;
		ret.dense[0..elementCount] = this.dense[0..elementCount];
		return ret;
	}
	
	///How many free slots there need to be in the dense array before it will be re-allocated to use less memory.
	@property shrinkThreshold() const nothrow @nogc pure @safe =>
		_shrinkThreshold;
	/**
	Change the shrink threshold.
	Note: Changing `shrinkThreshold` to a smaller value may invalidate references to the elements of the set.
	*/
	@property shrinkThreshold(Index val){
		bool smaller = val < _shrinkThreshold;
		_shrinkThreshold = val;
		if(smaller) tryShrink();
		return val;
	}
	
	///The number of indices in the sparse array. (i.e. the max set index + 1)
	@property uint sparseSize() const nothrow @nogc pure @safe =>
		cast(uint)this.sparse.length;
	/**
	Resizes the sparse array to `val` length.
	Note: When shrinking the sparse array, all elements with out-of-bounds indices will be removed, which may invalidate references to elements of the set.
	*/
	@property sparseSize(uint val){
		auto sparse = this.sparse;
		bool smaller = val < sparse.length;
		if(smaller){
			foreach(ind; val..sparse.length)
				tryRemove(cast(Index)ind);
		}
		allocator.resizeArray(sparse, val);
		this.sparse = sparse;
		if(smaller){
			if(dense.length > sparse.length){
				denseSize = cast(uint)sparse.length;
			}else{
				tryShrink();
			}
		}
		return val;
	}
	
	///The number of elements allocated for the dense array. May be higher than `.length`.
	@property uint denseSize() const nothrow @nogc pure @safe =>
		cast(uint)this.dense.length;
	/**
	Changes the number of elements allocated for the dense array.
	Params:
		val = The new number of elements to have allocated. Must be no less than `.length`, and no greater than `sparseSize`.
	*/
	@property denseSize(uint val)
	in(val >= elementCount)
	in(val <= this.sparse.length){
		import core.exception: onOutOfMemoryError;
		auto dense = this.dense;
		if(allocator.resizeArray(dense, val)){
			this.dense = dense;
		}else onOutOfMemoryError();
		return val;
	}
	
	//Re-allocates the dense array if it is smaller than the shrink threshold. Should be called whenever `elementCount` is decremented.
	private void tryShrink(){
		import core.exception: onOutOfMemoryError;
		auto dense = this.dense;
		if(dense.length - elementCount < shrinkThreshold){
			//do nothing
		}else if(elementCount){
			if(allocator.resizeArray(dense, elementCount)){
				this.dense = dense;
			}else onOutOfMemoryError();
		}else{
			clear();
		}
	}
	
	//Grows the dense array by 1.
	private void grow()
	in(this.dense.length < this.sparse.length){
		import core.exception: onOutOfMemoryError;
		import std.algorithm.comparison: min;
		auto dense = this.dense;
		if(elementCount < dense.length){
			//do nothing
		}else if(dense !is null){
			if(allocator.resizeArray(dense, min(elementCount + growAmount, this.sparse.length))){
				this.dense = dense;
			}else onOutOfMemoryError();
		}else{
			this.dense = allocator.newArray!ElementImpl(growAmount);
			if(_dense !is null){
			}else onOutOfMemoryError();
		}
		elementCount++;
	}
	
	/**
	Clears the set.
	Note: Should not be called when iterating over the result of `getElements`/`readElements`.
	*/
	void clear(bool runDestructors=true)(){
		if(_dense !is null){
			allocator.dispose!runDestructors(dense);
			_dense = null;
			elementCount = 0;
		}
	}
	
	///Dispose of this SparseSet, freeing its memory and invalidating it hereafter.
	void dispose(bool runDestructors=true)(){
		if(_dense !is null){
			allocator.dispose!runDestructors(dense);
			_dense = null;
		}
		if(_sparse !is null){
			allocator.dispose!runDestructors(sparse);
			_sparse = null;
		}
	}
	
	/**
	Removes element `ind` from the set. `ind` must be in the set.
	Note: Should not be called when iterating over the result of `getElements`/`readElements`.
	*/
	void remove(Index ind) @system
	in(this.has(ind)){
		dense[sparse[ind]] = dense[elementCount-1];
		static if(!is(Value == void)){
			dense[elementCount-1].value = Value.init;
		}
		sparse[dense[elementCount-1].index] = sparse[ind];
		elementCount--;
		tryShrink();
	}
	/**
	Tries to remove element `ind` from the set.
	Note: Should not be called when iterating over the result of `getElements`/`readElements`.
	Returns: `false` if the element didn't exist.
	*/
	bool tryRemove(Index ind) @system{
		if(this.has(ind)){
			dense[sparse[ind]] = dense[elementCount-1];
			static if(!is(Value == void)){
				dense[elementCount-1].value = Value.init;
			}
			sparse[dense[elementCount-1].index] = sparse[ind];
			elementCount--;
			tryShrink();
			return true;
		}else return false;
	}
	
	///Check whether element `ind` is in the set.
	bool has(Index ind) const nothrow @nogc pure @safe =>
		ind < sparse.length && sparse[ind] < elementCount && dense[sparse[ind]].index == ind;
	
	static if(is(Value == void)){
		///Return whether `ind` is in the set or not.
		bool opBinaryRight(string op: "in")(Index ind) const nothrow @nogc pure @safe =>
			this.has(ind);
		
		/**
		Add element `ind` to the set.
		Returns: `false` if element `ind` already existed.
		*/
		bool add(Index ind) nothrow
		in(ind < sparse.length){
			if(!this.has(ind)){
				sparse[ind] = elementCount;
				grow();
				dense[elementCount-1] = ElementImpl(ind);
				return true;
			}else return false;
		}
	}else{
		///Check if `ind` is in the set, and get a pointer to its associated value if so.
		inout(Value)* opBinaryRight(string op: "in")(Index ind) return inout nothrow @nogc pure @safe =>
			this.has(ind) ? &dense[sparse[ind]].value : null;
		
		/**
		Add element `ind` with associated `value` to the set.
		Returns: `false` if element `ind` already existed.
		*/
		bool add()(Index ind, auto ref Value value)
		in(ind < sparse.length){
			if(!this.has(ind)){
				sparse[ind] = elementCount;
				grow();
				dense[elementCount-1] = ElementImpl(ind, value);
				return true;
			}else return false;
		}
		
		///Get a pointer to the value of `ind`, which is assumed to be in the set.
		Value* get(Index ind) return nothrow @nogc pure @system
		in(this.has(ind)) =>
			&dense[sparse[ind]].value;
		/**
		Try to get a pointer to the value of `ind`.
		Returns: `null` if `ind` is not in the set.
		*/
		Value* tryGet(Index ind) return nothrow @nogc pure @safe =>
			this.has(ind) ? (() @trusted => &dense[sparse[ind]].value)(): null;
		
		///Get a const pointer to the value of `ind`, which is assumed to be in the set.
		const(Value)* read(Index ind) return const nothrow @nogc pure @system
		in(this.has(ind)) =>
			&dense[sparse[ind]].value;
		/**
		Try to get a const pointer to the value of `ind`.
		Returns: `null` if `ind` is not in the set.
		*/
		const(Value)* tryRead(Index ind) return const nothrow @nogc pure @safe =>
			this.has(ind) ? &dense[sparse[ind]].value : null;
	}
}
unittest{
	alias SS = SparseSet!(uint);
	auto set = SS(GCAllocator(), 40, 2, 1);
	set.add(0);
	set.add(2);
	set.add(4);
	set.add(5);
	set.remove(0);
	set.add(6);
	assert(set.length == 4);
	assert(set.readElements() == [SS.Element(5), SS.Element(2), SS.Element(4), SS.Element(6)]);
	assert( set.has(5));
	assert(!set.has(0));
	assert(4 in set);
	assert(7 !in set);
	foreach(element; set.readElements()){
		set.add(cast(SS.Index)(element.index+1));
	}
	assert(set.length == 6);
	assert(set.readElements == [SS.Element(5), SS.Element(2), SS.Element(4), SS.Element(6), SS.Element(3), SS.Element(7)]);
	set.clear();
	assert(set.length == 0);
	assert(set.readElements == []);
}
unittest{
	alias SS = SparseSet!(ushort, string);
	auto set = SS(GCAllocator(), 40, 2, 1);
	set.add(0, "Testing");
	set.add(2, "Hello");
	set.add(4, "World");
	set.add(5, ":)");
	set.remove(0);
	set.add(6, ":O");
	assert(set.getElements() == [SS.Element(5, ":)"), SS.Element(2, "Hello"), SS.Element(4, "World"), SS.Element(6, ":O")]);
	assert( set.has(5));
	assert(!set.has(0));
	assert(4 in set);
	assert(7 !in set);
	assert(*(4 in set) == "World");
	assert(*set.read(4) == "World");
	*set.get(4) = "Dlrow";
	assert(*(4 in set) == "Dlrow");
}

version(unittest){
	version(D_BetterC){
		extern(C) void main(){
			import core.stdc.stdio;
			static foreach(test; __traits(getUnitTests, sparse)){
				printf("Running test…\n");
				test();
			}
			printf("All tests passed.\n");
		}
	}
}
