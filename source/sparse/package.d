/+
+            Copyright 2024 – 2025 Aya Partridge
+ Distributed under the Boost Software License, Version 1.0.
+     (See accompanying file LICENSE_1_0.txt or copy at
+           http://www.boost.org/LICENSE_1_0.txt)
+/
module sparse;

import std.traits: isIntegral;
import memterface.allocator.gc, memterface.iface;

///The smallest integer that can fully index a sparse array with size `indices`.
template SparseSetIndex(ulong indices){
	static if(indices <= ubyte.max+1){
		alias SparseSetIndex = ubyte;
	}else static if(indices <= ushort.max+1){
		alias SparseSetIndex = ushort;
	}else static if(indices <= uint.max+1L){
		alias SparseSetIndex = uint;
	}else{
		alias SparseSetIndex = ulong;
	}
}

struct SparseSetElement(Index, Value)
if(isIntegral!Index && __traits(isUnsigned, Index)){
	Index ind;
	static if(!is(Value == void)){
		Value value;
	}
}

alias StaticSparseSet = SparseSet;
/**
A classic sparse set using static arrays.
Can optionally store an arbitrary type in order to act as a map.
Params:
	Value_ = What value to store with the items in the dense array. `void` for none.
	indices_ = How many indices there should be in the sparse array. (i.e. the max index + 1)
	capacity_ = How many elements can be held in the dense array. (i.e. how many elements can be stored at once)
*/
struct SparseSet(Value_=void, ulong indices_, ulong capacity_=indices_){
	enum indices = indices_;
	enum capacity = capacity_;
	static assert(capacity <= indices, "Unnecessarily large `capacity`. Should be at most equal to `indices`");
	static assert(indices > 0, "`indices` must be greater than 0.");
	static assert(capacity > 0, "`capacity` must be greater than 0.");
	alias Value = Value_;
	alias Index = SparseSetIndex!indices;
	alias Element = SparseSetElement!(Index, Value);
	
	Element[capacity] dense; ///A list of indices into `sparse`, each with an optional `Value`. The indices should not be modified from outside. Can be read (somewhat) safely with `denseElements`/`denseElementsConst`.
	Index[indices] sparse; ///A list of indices into `dense`. Should not be modified from outside.
	Index elementCount = 0; ///The number of elements currently stored in `dense`. Should not be modified from outside. Can be read safely with `length`.
	
	///The number of elements in the set.
	@property Index length() const nothrow @nogc pure @safe =>
		elementCount;
	
	@property Index capacityLeft() const nothrow @nogc pure @safe =>
		cast(Index)(capacity - elementCount);
	
	///A slice containing the elements in the set.
	@property Element[] denseElements() return nothrow @nogc pure @safe =>
		dense[0..elementCount];
	///A read-only slice containing the elements in the set.
	@property const(Element)[] denseElementsConst() return const nothrow @nogc pure @safe =>
		dense[0..elementCount];
	
	///Clears the set. Should not be called when iterating over `denseElements`.
	void clear() nothrow @nogc pure @safe{
		elementCount = 0;
	}
	
	///Remove element `ind` from the set. Should not be called when iterating over `denseElements`.
	void remove(bool erase=!is(Value == void))(Index ind)
	in(this.has(ind)){
		dense[sparse[ind]] = dense[elementCount-1];
		static if(erase){
			dense[elementCount-1].value = Value.init;
		}
		sparse[dense[elementCount-1].ind] = sparse[ind];
		elementCount--;
	}
	///Try to remove element `ind` from the set. Returns `false` if the element didn't exist. Should not be called when iterating over array `denseElements`.
	bool tryRemove(bool erase=!is(Value == void))(Index ind){
		if(this.has(ind)){
			dense[sparse[ind]] = dense[elementCount-1];
			static if(erase){
				dense[elementCount-1].value = Value.init;
			}
			sparse[dense[elementCount-1].ind] = sparse[ind];
			elementCount--;
			return true;
		}else return false;
	}
	
	///Check whether element `ind` is in the set.
	bool has(Index ind) const nothrow @nogc pure @safe
	in(ind < indices) =>
		sparse[ind] < elementCount && dense[sparse[ind]].ind == ind;
	
	static if(is(Value == void)){
		///Return whether `ind` is in the set or not.
		bool opBinaryRight(string op: "in")(Index ind) const nothrow @nogc pure @safe =>
			this.has(ind);
		
		///Add element `ind` to the set. Returns `false` if there's no space left, or element `ind` already existed.
		bool add(Index ind) nothrow @nogc pure @safe
		in(ind < indices){
			if(elementCount < capacity && !this.has(ind)){
				dense[elementCount] = Element(ind);
				sparse[ind] = elementCount;
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
		in(ind < indices){
			if(elementCount < capacity && !this.has(ind)){
				dense[elementCount] = Element(ind, value);
				sparse[ind] = elementCount;
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
	alias SS = SparseSet!(void, 40, 20);
	alias SSE = SS.Element;
	SS set;
	set.add(0);
	set.add(2);
	set.add(4);
	set.add(5);
	set.remove(0);
	set.add(6);
	assert(set.length == 4);
	assert(set.denseElementsConst == [SSE(5), SSE(2), SSE(4), SSE(6)]);
	assert( set.has(5));
	assert(!set.has(0));
	assert(4 in set);
	assert(7 !in set);
	foreach(element; set.denseElementsConst){
		set.add(cast(SS.Index)(element.ind+1));
	}
	assert(set.length == 6);
	assert(set.denseElementsConst == [SSE(5), SSE(2), SSE(4), SSE(6), SSE(3), SSE(7)]);
	set.clear();
	assert(set.length == 0);
	assert(set.denseElementsConst == []);
}
unittest{
	alias SS = SparseSet!(string, 40, 20);
	alias SSE = SS.Element;
	SS set;
	set.add(0, "Testing");
	set.add(2, "Hello");
	set.add(4, "World");
	set.add(5, ":)");
	set.remove(0);
	set.add(6, ":O");
	assert(set.dense[0..set.length] == [SSE(5, ":)"), SSE(2, "Hello"), SSE(4, "World"), SSE(6, ":O")]);
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
	Value_ = What value to store with the items in the dense array. `void` for none.
	indices_ = How many indices there should be in the sparse array. (i.e. the max index + 1)
	Allocator_ = What type of allocator is used to allocate the dense array.
*/
struct DynamicSparseSet(Value_=void, size_t indices_, Allocator_=GCAllocator)
if(isAllocator!Allocator_){
	enum indices = indices_;
	static assert(indices > 0, "`indices` must be greater than 0");
	alias Value = Value_;
	alias Index = SparseSetIndex!indices;
	alias Element = SparseSetElement!(Index, Value);
	alias Allocator = Allocator_;
	
	Element[] denseAsAllocated; ///A version of `dense` that never gets re-sliced after being allocated in order to facilitate passing it back into the allocator. Should not be modified directly.
	Element[] dense; ///A list of indices into `sparse`, each with an optional `Value`. The indices should not be modified directly. Can be read (somewhat) safely with `.denseElements`/`.denseElementsConst`.
	Index[indices] sparse; ///A list of indices into `dense`. Should not be modified directly.
	Allocator allocator;
	size_t growAmount = 16; ///How many extra elements to allocate at once when the dense array needs to grow.
	size_t shrinkThreshold = 48; ///How many free slots there need to be in the dense array before it will be re-allocated to use less memory.
	
	bool assertValidGrowthShrink() nothrow @nogc pure @safe{
		assert(growAmount      >= 1 && growAmount      <= indices,      "`growAmount` must be in the range of 1 to `indices`");
		assert(shrinkThreshold >= 1 && shrinkThreshold <= indices, "`shrinkThreshold` must be in the range of 1 to `indices`");
		return true;
	}
	
	import memterface.ctor;
	
	this()(auto ref Allocator allocator, size_t growAmount=16, size_t shrinkThreshold=48)
	out(; assertValidGrowthShrink()){
		this.allocator = allocator;
		this.growAmount = growAmount;
		this.shrinkThreshold = shrinkThreshold;
	}
	
	///The number of elements in the set.
	@property Index length() const nothrow @nogc pure @safe =>
		cast(Index)dense.length;
	
	///A slice containing the elements in the set.
	@property Element[] denseElements() return nothrow @nogc pure @safe =>
		dense[];
	///A read-only slice containing the elements in the set.
	@property const(Element)[] denseElementsConst() return const nothrow @nogc pure @safe =>
		dense[];
	
	///Duplicates the set and returns a new set allocated with `allocator`.
	DynamicSparseSet!(Value, indices, A) dup(A=Allocator)(Allocator allocator) nothrow{
		auto ret = DynamicSparseSet!(Value, indices, A)(allocator, growAmount, shrinkThreshold);
		ret.denseAsAllocated = allocator.newArray!Element(this.denseAsAllocated.length);
		ret.dense = ret.denseAsAllocated[0..this.dense.length];
		ret.dense[] = this.dense[];
		ret.sparse[] = this.sparse[];
		return ret;
	}
	
	//Re-allocates the dense array if it is smaller than the shrink threshold. Should be called whenever the dense array is sliced to be smaller.
	private void tryShrink()
	in(assertValidGrowthShrink()){
		if(denseAsAllocated.length - dense.length < shrinkThreshold){
			//do nothing
		}else if(dense.length){
			bool resized = allocator.resizeArray(denseAsAllocated, dense.length);
			assert(resized);
		}else{
			clear();
		}
	}
	
	//Grows the dense array by 1.
	private void grow()
	in(dense.length < indices)
	in(assertValidGrowthShrink()){
		import core.exception;
		import std.algorithm.comparison: min;
		if(dense.length < denseAsAllocated.length){
			//do nothing
		}else if(denseAsAllocated !is null){
			if(allocator.resizeArray(denseAsAllocated, min(dense.length + growAmount, indices))){
			}else onOutOfMemoryError();
		}else{
			denseAsAllocated = allocator.newArray!Element(growAmount);
			if(denseAsAllocated !is null){
			}else onOutOfMemoryError();
		}
		dense = denseAsAllocated[0..dense.length+1];
	}
	
	/**
	Changes the number of elements allocated for the dense array.
	Params:
		newLength = The new number of elements to have allocated. Must be no less than `.length`, and no greater than `indices`.
	*/
	void resizeDense(size_t newLength)
	in(newLength >= dense.length)
	in(newLength <= indices){
		import core.exception;
		if(allocator.resizeArray(denseAsAllocated, newLength)){
			dense = denseAsAllocated[0..dense.length];
		}else onOutOfMemoryError();
	}
	
	///Clears the set. Should not be called when iterating over `denseElements`.
	void clear(bool runDestructors=!is(Value == void))(){
		if(denseAsAllocated !is null){
			allocator.dispose!runDestructors(denseAsAllocated);
			dense = null;
		}
	}
	
	///Removes element `ind` from the set. Should not be called when iterating over `denseElements`.
	void remove(bool erase=!is(Value == void))(Index ind)
	in(this.has(ind)){
		dense[sparse[ind]] = dense[$-1];
		static if(erase){
			dense[$-1].value = Value.init;
		}
		sparse[dense[$-1].ind] = sparse[ind];
		dense = dense[0..$-1];
		tryShrink();
	}
	/**
	Tries to remove element `ind` from the set.
	Should not be called when iterating over array `denseElements`.
	Returns: `false` if the element didn't exist.
	*/
	bool tryRemove(bool erase=!is(Value == void))(Index ind){
		if(this.has(ind)){
			dense[sparse[ind]] = dense[$-1];
			static if(erase){
				dense[$-1].value = Value.init;
			}
			sparse[dense[$-1].ind] = sparse[ind];
			dense = dense[0..$-1];
			tryShrink();
			return true;
		}else return false;
	}
	
	///Check whether element `ind` is in the set.
	bool has(Index ind) const nothrow @nogc pure @safe
	in(ind < indices) =>
		sparse[ind] < dense.length && dense[sparse[ind]].ind == ind;
	
	static if(is(Value == void)){
		///Return whether `ind` is in the set or not.
		bool opBinaryRight(string op: "in")(Index ind) const nothrow @nogc pure @safe =>
			this.has(ind);
		
		/**
		Add element `ind` to the set.
		Returns: `false` if element `ind` already existed.
		*/
		bool add(Index ind) nothrow
		in(ind < indices){
			if(!this.has(ind)){
				sparse[ind] = cast(Index)dense.length;
				grow();
				dense[$-1] = Element(ind);
				return true;
			}else return false;
		}
	}else{
		///Check if `ind` is in the set, and get a pointer to its associated value if so.
		inout(Value)* opBinaryRight(string op: "in")(Index ind) return inout nothrow @nogc pure @safe =>
			ind < indices && this.has(ind) ? &dense[sparse[ind]].value : null;
		
		/**
		Add element `ind` with associated `value` to the set.
		Returns: `false` if element `ind` already existed.
		*/
		bool add()(Index ind, auto ref Value value)
		in(ind < indices){
			if(!this.has(ind)){
				sparse[ind] = cast(Index)dense.length;
				grow();
				dense[$-1] = Element(ind, value);
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
	alias SS = DynamicSparseSet!(void, 40);
	auto set = SS(GCAllocator(), 2, 1);
	set.add(0);
	set.add(2);
	set.add(4);
	set.add(5);
	set.remove(0);
	set.add(6);
	assert(set.length == 4);
	assert(set.denseElementsConst == [SS.Element(5), SS.Element(2), SS.Element(4), SS.Element(6)]);
	assert( set.has(5));
	assert(!set.has(0));
	assert(4 in set);
	assert(7 !in set);
	foreach(element; set.denseElementsConst){
		set.add(cast(SS.Index)(element.ind+1));
	}
	assert(set.length == 6);
	assert(set.denseElementsConst == [SS.Element(5), SS.Element(2), SS.Element(4), SS.Element(6), SS.Element(3), SS.Element(7)]);
	set.clear();
	assert(set.length == 0);
	assert(set.denseElementsConst == []);
}
unittest{
	alias SS = DynamicSparseSet!(string, 40);
	auto set = SS(GCAllocator(), 2, 1);
	set.add(0, "Testing");
	set.add(2, "Hello");
	set.add(4, "World");
	set.add(5, ":)");
	set.remove(0);
	set.add(6, ":O");
	assert(set.dense[0..set.length] == [SS.Element(5, ":)"), SS.Element(2, "Hello"), SS.Element(4, "World"), SS.Element(6, ":O")]);
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
