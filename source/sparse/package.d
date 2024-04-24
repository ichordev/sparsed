module sparse;

template SparseSetIndex(size_t capacity){
	static if(capacity <= ubyte.max){
		alias SparseSetIndex = ubyte;
	}else static if(capacity <= ushort.max){
		alias SparseSetIndex = ushort;
	}else static if(capacity <= uint.max){
		alias SparseSetIndex = uint;
	}else{
		alias SparseSetIndex = ulong;
	}
}

/**
A classic sparse set using static arrays.
Can optionally store an arbitrary type in order to act as a map.
*/
struct SparseSet(size_t capacity_, Value_=void){
	alias capacity = capacity_;
	alias Value = Value_;
	alias Index = SparseSetIndex!capacity;
	
	struct Dense{
		Index ind;
		static if(!is(Value == void)){
			Value value;
		}
	}
	Dense[capacity] dense;
	Index[capacity] sparse;
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
	in(ind < capacity) =>
		sparse[ind] < elements && dense[sparse[ind]].ind == ind;
	
	static if(is(Value == void)){
		bool opBinaryRight(string op: "in")(Index ind) nothrow @nogc pure @safe =>
			this.has(ind);
		
		///Add element `ind`.
		bool add(Index ind) nothrow @nogc pure @safe{
			if(elements >= capacity)
				return false;
			dense[elements] = Dense(ind);
			sparse[ind] = elements;
			elements++;
			return true;
		}
	}else{
		Value* opBinaryRight(string op: "in")(Index ind) nothrow @nogc pure @safe{
			if(this.has(ind)){
				return &dense[ind].value;
			}
			return null;
		}
		
		///Add element `ind` with associated `value`.
		bool add(Index ind, Value value) nothrow @nogc pure @safe{
			if(elements >= capacity)
				return false;
			dense[elements] = Dense(ind, value);
			sparse[ind] = elements;
			elements++;
			return true;
		}
	}
}

unittest{
	alias Set = SparseSet!(40, void);
	Set set;
	set.add(0);
	set.add(2);
	set.add(4);
	set.add(5);
	set.remove(0);
	set.add(6);
	assert(set.dense[0..set.length] == [Set.Dense(5), Set.Dense(2), Set.Dense(4), Set.Dense(6)]);
	assert( set.has(5));
	assert(!set.has(0));
	assert(4 in set);
}

unittest{
	alias Set = SparseSet!(40, string);
	Set set;
	set.add(0, "Testing");
	set.add(2, "Hello");
	set.add(4, "World");
	set.add(5, ":)");
	set.remove(0);
	set.add(6, ":O");
	assert(set.dense[0..set.length] == [Set.Dense(5, ":)"), Set.Dense(2, "Hello"), Set.Dense(4, "World"), Set.Dense(6, ":O")]);
	assert( set.has(5));
	assert(!set.has(0));
	//assert(*(4 in set) == "World"); //FIXME: Returns pointer to empty string?
}
