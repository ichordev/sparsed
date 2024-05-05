/+
+               Copyright 2024 Aya Partridge
+ Distributed under the Boost Software License, Version 1.0.
+     (See accompanying file LICENSE_1_0.txt or copy at
+           http://www.boost.org/LICENSE_1_0.txt)
+/
module sparse;

///The smallest integer that can fully index a sparse array with size `indices`.
template SparseSetIndex(size_t indices){
	static if(indices <= ubyte.max){
		alias SparseSetIndex = ubyte;
	}else static if(indices <= ushort.max){
		alias SparseSetIndex = ushort;
	}else static if(indices <= uint.max){
		alias SparseSetIndex = uint;
	}else{
		alias SparseSetIndex = ulong;
	}
}

/**
A classic sparse set using static arrays.
Can optionally store an arbitrary type in order to act as a map.
Params:
	Value_ = what value to store with the items in the dense array. `void` for none.
	indices_ = how many indices there should be in the sparse array. (i.e. the max index + 1)
	capacity_ = how many elements can be held in the dense array. (i.e. how many elements can be stored at once)
*/
struct SparseSet(Value_=void, size_t indices_, size_t capacity_=indices_){
	enum indices = indices_;
	enum capacity = capacity_;
	static assert(capacity <= indices, "Unnecessarily large `capacity`. Should be at most equal to `indices`");
	static assert(indices > 0, "`indices` must be greater than 0.");
	static assert(capacity > 0, "`capacity` must be greater than 0.");
	alias Value = Value_;
	alias Index = SparseSetIndex!indices;
	
	struct Element{
		Index ind;
		static if(!is(Value == void)){
			Value value;
		}
	}
	
	Element[capacity] dense; ///A list of indices into `sparse`, each with an optional `Value`. The indices should not be modified from outside. Can be read (somewhat) safely with `denseElements`/`denseElementsConst`.
	Index[indices] sparse; ///A list of indices into `dense`. Should not be modified from outside.
	Index elementCount = 0; ///The number of elements currently stored in `dense`. Should not be modified from outside. Can be read safely with `length`.
	
	///The number of elements in the set.
	@property Index length() const nothrow @nogc pure @safe =>
		elementCount;
	
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
	void remove(Index ind) nothrow @nogc pure @safe
	in(this.has(ind)){
		dense[sparse[ind]] = dense[elementCount-1];
		sparse[dense[elementCount-1].ind] = sparse[ind];
		elementCount--;
	}
	static if(!is(Value == void)){
		///Remove element `ind` from the set, and initialise any copied elements. Should not be called when iterating over `denseElements`.
		void removeErase(Index ind) nothrow @nogc pure @safe
		in(this.has(ind)){
			dense[sparse[ind]] = dense[elementCount-1];
			dense[elementCount-1].value = Value.init;
			sparse[dense[elementCount-1].ind] = sparse[ind];
			elementCount--;
		}
	}
	
	///Check whether element `ind` is in the set.
	bool has(Index ind) const nothrow @nogc pure @safe
	in(ind < indices) =>
		sparse[ind] < elementCount && dense[sparse[ind]].ind == ind;
	
	static if(is(Value == void)){
		///Return whether `ind` is in the set or not.
		bool opBinaryRight(string op: "in")(Index ind) const nothrow @nogc pure @safe =>
			this.has(ind);
		
		///Add element `ind` to the set. Returns false if there's no space left.
		bool add(Index ind) nothrow @nogc pure @safe
		in(ind < indices){
			if(elementCount >= capacity || this.has(ind))
				return false;
			dense[elementCount] = Element(ind);
			sparse[ind] = elementCount;
			elementCount++;
			return true;
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
		
		///Add element `ind` with associated `value` to the set.
		bool add(Index ind, Value value) nothrow @nogc pure @safe
		in(ind < indices){
			if(elementCount >= capacity || this.has(ind))
				return false;
			dense[elementCount] = Element(ind, value);
			sparse[ind] = elementCount;
			elementCount++;
			return true;
		}
		
		///Get a pointer to the value of `ind`, which is assumed to be in the set.
		Value* get(Index ind) return nothrow @nogc pure @safe
		in(this.has(ind)) =>
			&dense[sparse[ind]].value;
		
		///Get a const pointer to the value of `ind`, which is assumed to be in the set.
		const(Value)* read(Index ind) return const nothrow @nogc pure @safe
		in(this.has(ind)) =>
			&dense[sparse[ind]].value;
	}
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

unittest{
	alias Set = SparseSet!(void, 40, 20);
	Set set;
	set.add(0);
	set.add(2);
	set.add(4);
	set.add(5);
	set.remove(0);
	set.add(6);
	assert(set.length == 4);
	assert(set.denseElementsConst == [Set.Element(5), Set.Element(2), Set.Element(4), Set.Element(6)]);
	assert( set.has(5));
	assert(!set.has(0));
	assert(4 in set);
	assert(7 !in set);
	foreach(element; set.denseElementsConst){
		set.add(cast(Set.Index)(element.ind+1));
	}
	assert(set.length == 6);
	assert(set.denseElementsConst == [Set.Element(5), Set.Element(2), Set.Element(4), Set.Element(6), Set.Element(3), Set.Element(7)]);
	set.clear();
	assert(set.length == 0);
	assert(set.denseElementsConst == []);
}

unittest{
	alias Set = SparseSet!(string, 40, 20);
	Set set;
	set.add(0, "Testing");
	set.add(2, "Hello");
	set.add(4, "World");
	set.add(5, ":)");
	set.remove(0);
	set.add(6, ":O");
	assert(set.dense[0..set.length] == [Set.Element(5, ":)"), Set.Element(2, "Hello"), Set.Element(4, "World"), Set.Element(6, ":O")]);
	assert( set.has(5));
	assert(!set.has(0));
	assert(4 in set);
	assert(7 !in set);
	assert(*(4 in set) == "World");
	assert(*set.read(4) == "World");
	*set.get(4) = "Dlrow";
	assert(*(4 in set) == "Dlrow");
}
