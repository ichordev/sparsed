module sparse;

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
	alias Value = Value_;
	alias Index = SparseSetIndex!indices;
	
	struct Element{
		Index ind;
		static if(!is(Value == void)){
			Value value;
		}
	}
	Element[capacity] dense;
	Index[indices] sparse;
	private Index elements = 0; ///The number of elements currently stored in `dense`.
	
	///Returns the number of elements in the set.
	@property Index length() nothrow @nogc pure @safe =>
		elements;
	
	///Clears the set.
	void clear() nothrow @nogc pure @safe{
		elements = 0;
	}
	
	///Remove element `ind` from the set.
	void remove(Index ind) nothrow @nogc pure @safe
	in(this.has(ind)){
		dense[sparse[ind]] = dense[elements-1];
		sparse[dense[elements-1].ind] = sparse[ind];
		elements--;
	}
	
	///Check whether element `ind` is in the set.
	bool has(Index ind) nothrow @nogc pure @safe
	in(ind < indices) =>
		sparse[ind] < elements && dense[sparse[ind]].ind == ind;
	
	static if(is(Value == void)){
		bool opBinaryRight(string op: "in")(Index ind) nothrow @nogc pure @safe =>
			this.has(ind);
		
		///Add element `ind`.
		bool add(Index ind) nothrow @nogc pure @safe
		in(ind < indices){
			if(elements >= capacity)
				return false;
			dense[elements] = Element(ind);
			sparse[ind] = elements;
			elements++;
			return true;
		}
	}else{
		Value* opBinaryRight(string op: "in")(Index ind) nothrow @nogc pure @safe{
			if(this.has(ind)){
				return &dense[sparse[ind]].value;
			}
			return null;
		}
		
		///Add element `ind` with associated `value`.
		bool add(Index ind, Value value) nothrow @nogc pure @safe
		in(ind < indices){
			if(elements >= capacity)
				return false;
			dense[elements] = Element(ind, value);
			sparse[ind] = elements;
			elements++;
			return true;
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
	assert(set.dense[0..set.length] == [Set.Element(5), Set.Element(2), Set.Element(4), Set.Element(6)]);
	assert( set.has(5));
	assert(!set.has(0));
	assert(4 in set);
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
	assert(*(4 in set) == "World");
}
