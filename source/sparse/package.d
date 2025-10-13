/+
+            Copyright 2024 – 2025 Aya Partridge
+ Distributed under the Boost Software License, Version 1.0.
+     (See accompanying file LICENSE_1_0.txt or copy at
+           http://www.boost.org/LICENSE_1_0.txt)
+/
module sparse;

import std.traits: isIntegral;
import memterface.allocator.gc, memterface.iface;

///The smallest integer that can fully index a static sparse array with `sparseSize``.
template SparseSetIndex(uint sparseSize){
	static if(sparseSize <= ubyte.max+1){
		alias SparseSetIndex = ubyte;
	}else static if(sparseSize <= ushort.max+1){
		alias SparseSetIndex = ushort;
	}else{
		alias SparseSetIndex = uint;
	}
}

template SparseSetElement(Index, Value)
if(isIntegral!Index && __traits(isUnsigned, Index)){
	alias SparseSetElement = SparseSetElementImpl!(const Index, Value);
}

private struct SparseSetElementImpl(Index, Value){
	Index ind;
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
	alias Index = SparseSetIndex!sparseSize;
	alias Value = Value_;
	alias Element = SparseSetElement!(Index, Value);
	
	private{
		alias ElementImpl = SparseSetElementImpl!(Index, Value);
		//A list of indices into `dense`.
		Index[sparseSize] sparse;
		//The number of elements currently stored in `dense`. Can be read safely with `length`.
		size_t elementCount = 0;
		//A list of indices into `sparse`, each with an optional `Value`.
		ElementImpl[denseSize] dense;
	}
	
	///The number of elements in the set.
	@property size_t length() const nothrow @nogc pure @safe =>
		elementCount;
	
	///How many more elements can be added to the set before we run out of space.
	@property size_t capacityLeft() const nothrow @nogc pure @safe =>
		dense.length - elementCount;
	
	static if(!is(Value == void)){
		///Gets a slice containing the elements in the set.
		Element[] getElements() return nothrow @nogc pure @trusted =>
			cast(Element[])dense[0..elementCount];
	}
	///Gets a read-only slice containing the elements in the set.
	const(Element)[] readElements() return const nothrow @nogc pure @trusted =>
		cast(const(Element)[])dense[0..elementCount];
	
	///Clears the set. Should not be called when iterating over the result of `getElements`/`readElements`.
	void clear() nothrow @nogc pure @safe{
		elementCount = 0;
	}
	
	///Remove element `ind` from the set. Should not be called when iterating over the result of `getElements`/`readElements`.
	void remove(Index ind)
	in(this.has(ind)){
		dense[sparse[ind]] = dense[elementCount-1];
		static if(!is(Value == void)){
			dense[elementCount-1].value = Value.init;
		}
		sparse[dense[elementCount-1].ind] = sparse[ind];
		elementCount--;
	}
	///Try to remove element `ind` from the set. Returns `false` if the element didn't exist. Should not be called when iterating over the result of `getElements`/`readElements`.
	bool tryRemove(Index ind){
		if(this.has(ind)){
			dense[sparse[ind]] = dense[elementCount-1];
			static if(!is(Value == void)){
				dense[elementCount-1].value = Value.init;
			}
			sparse[dense[elementCount-1].ind] = sparse[ind];
			elementCount--;
			return true;
		}else return false;
	}
	
	///Check whether element `ind` is in the set.
	bool has(Index ind) const nothrow @nogc pure @safe =>
		ind < sparse.length && sparse[ind] < elementCount && dense[sparse[ind]].ind == ind;
	
	static if(is(Value == void)){
		///Return whether `ind` is in the set or not.
		bool opBinaryRight(string op: "in")(Index ind) const nothrow @nogc pure @safe =>
			this.has(ind);
		
		///Add element `ind` to the set. Returns `false` if there's no space left, or element `ind` already existed.
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
		Value* opBinaryRight(string op: "in")(Index ind) return nothrow @nogc pure @safe{
			if(this.has(ind)){
				return &dense[sparse[ind]].value;
			}
			return null;
		}
		///Check if `ind` is in the set, and get a pointer to its associated value if so.
		const(Value)* opBinaryRight(string op: "in")(Index ind) return const nothrow @nogc pure @safe{
			if(this.has(ind)){
				return &dense[sparse[ind]].value;
			}
			return null;
		}
		
		///Add element `ind` with associated `value` to the set. Returns `false` if there's no space left, or element `ind` already existed.
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
		Value* get(Index ind) return nothrow @nogc pure @safe
		in(this.has(ind)) =>
			&dense[sparse[ind]].value;
		///Try to get a pointer to the value of `ind`. Returns `null` if `ind` is not in the set.
		Value* tryGet(Index ind) return nothrow @nogc pure @safe =>
			this.has(ind) ? &dense[sparse[ind]].value : null;
		
		///Get a const pointer to the value of `ind`, which is assumed to be in the set.
		const(Value)* read(Index ind) return const nothrow @nogc pure @safe
		in(this.has(ind)) =>
			&dense[sparse[ind]].value;
		///Try to get a const pointer to the value of `ind`. Returns `null` if `ind` is not in the set.
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
		set.add(cast(SS.Index)(element.ind+1));
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
Unless using `GCAllocator`, when an instance is no longer in-use its data must be freed with `.clear()` to avoid memory leaks.
Params:
	Index_ = The type to use for indices in the sparse and dense arrays. Must be a `ubyte`, `ushort`, or `uint`.
	Value_ = What value to store with the items in the dense array. `void` for none.
	Allocator_ = What type of allocator is used to allocate the dense array.
*/
struct SparseSet(Index_=uint, Value_=void, Allocator_=GCAllocator)
if(isIntegral!Index_ && __traits(isUnsigned, Index_) && Index_.sizeof <= uint.sizeof && isAllocator!Allocator_){
	alias Index = Index_;
	alias Value = Value_;
	alias Allocator = Allocator_;
	alias Element = SparseSetElement!(Index, Value);
	
	///How many extra elements to allocate at once when the dense array needs to grow.
	size_t growAmount = 16;
	private{
		alias ElementImpl = SparseSetElementImpl!(Index, Value);
		///How many free slots there need to be in the dense array before it will be re-allocated to use less memory.
		size_t _shrinkThreshold = 48;
		//A list of indices into `dense`.
		Index[] sparse;
		//The number of elements currently stored in `dense`. Can be read safely with `length`.
		size_t elementCount = 0;
		//A list of indices into `sparse`, each with an optional `Value`.
		ElementImpl[] dense;
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
	@property size_t length() const nothrow @nogc pure @safe =>
		elementCount;
	
	static if(!is(Value == void)){
		///Gets a slice containing the elements in the set.
		Element[] getElements() return nothrow @nogc pure @trusted =>
			cast(Element[])dense[0..elementCount];
	}
	///Gets a read-only slice containing the elements in the set.
	const(Element)[] readElements() return const nothrow @nogc pure @trusted =>
		cast(const(Element)[])dense[0..elementCount];
	
	///Duplicates the set and returns a new set allocated with `allocator`.
	SparseSet!(Index, Value, A) dup(A=Allocator)(auto ref A allocator) nothrow{
		auto ret = SparseSet!(Value, indices, A)(allocator, sparse.length, growAmount, shrinkThreshold);
		ret.sparse[] = sparse[];
		ret.elementCount = elementCount;
		ret.denseSize = dense.length;
		ret.dense[0..elementCount] = this.dense[0..elementCount];
		return ret;
	}
	
	@property shrinkThreshold() const nothrow @nogc pure @safe =>
		_shrinkThreshold;
	@property shrinkThreshold(size_t val){
		_shrinkThreshold = val;
		tryShrink();
		return val;
	}
	
	@property sparseSize() const nothrow @nogc pure @safe =>
		sparse.length;
	/**
	Resizes the sparse array to `val` length.
	When shrinking the sparse array, all out-of-bounds items will be removed.
	*/
	@property sparseSize(size_t val){
		if(val < sparse.length){
			foreach(ind; val..sparse.length)
				tryRemove(cast(Index)ind);
		}
		allocator.resizeArray(sparse, val);
		if(dense.length > sparse.length){
			denseSize = sparse.length;
		}else{
			tryShrink();
		}
		return val;
	}
	
	///The number of elements allocated for the dense array. May be higher than `.length`.
	@property denseSize() const nothrow @nogc pure @safe =>
		dense.length;
	/**
	Changes the number of elements allocated for the dense array.
	Params:
		val = The new number of elements to have allocated. Must be no less than `.length`, and no greater than `sparseSize`.
	*/
	@property denseSize(size_t val)
	in(val >= elementCount)
	in(val <= sparse.length){
		import core.exception;
		if(allocator.resizeArray(dense, val)){
		}else onOutOfMemoryError();
		return val;
	}
	
	//Re-allocates the dense array if it is smaller than the shrink threshold. Should be called whenever `elementCount` is decremented.
	private void tryShrink(){
		if(dense.length - elementCount < shrinkThreshold){
			//do nothing
		}else if(elementCount){
			bool resized = allocator.resizeArray(dense, elementCount);
			assert(resized);
		}else{
			clear();
		}
	}
	
	//Grows the dense array by 1.
	private void grow()
	in(dense.length < sparse.length){
		import core.exception;
		import std.algorithm.comparison: min;
		if(elementCount < dense.length){
			//do nothing
		}else if(dense !is null){
			if(allocator.resizeArray(dense, min(elementCount + growAmount, sparse.length))){
			}else onOutOfMemoryError();
		}else{
			dense = allocator.newArray!ElementImpl(growAmount);
			if(dense !is null){
			}else onOutOfMemoryError();
		}
		elementCount++;
	}
	
	/**
	Clears the set.
	Note: Should not be called when iterating over the result of `getElements`/`readElements`.
	*/
	void clear(){
		if(dense !is null){
			allocator.dispose(dense);
			elementCount = 0;
		}
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
		sparse[dense[elementCount-1].ind] = sparse[ind];
		elementCount--;
		tryShrink();
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
			sparse[dense[elementCount-1].ind] = sparse[ind];
			elementCount--;
			tryShrink();
			return true;
		}else return false;
	}
	
	///Check whether element `ind` is in the set.
	bool has(Index ind) const nothrow @nogc pure @safe =>
		ind < sparse.length && sparse[ind] < elementCount && dense[sparse[ind]].ind == ind;
	
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
				sparse[ind] = cast(Index)elementCount;
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
				sparse[ind] = cast(Index)elementCount;
				grow();
				dense[elementCount-1] = ElementImpl(ind, value);
				return true;
			}else return false;
		}
		
		///Get a pointer to the value of `ind`, which is assumed to be in the set.
		Value* get(Index ind) return nothrow @nogc pure @safe
		in(this.has(ind)) =>
			&dense[sparse[ind]].value;
		/**
		Try to get a pointer to the value of `ind`.
		Returns: `null` if `ind` is not in the set.
		*/
		Value* tryGet(Index ind) return nothrow @nogc pure @safe =>
			this.has(ind) ? &dense[sparse[ind]].value : null;
		
		///Get a const pointer to the value of `ind`, which is assumed to be in the set.
		const(Value)* read(Index ind) return const nothrow @nogc pure @safe
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
		set.add(cast(SS.Index)(element.ind+1));
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
