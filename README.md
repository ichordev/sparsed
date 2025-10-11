# SparseD
Incredibly simple & super-fast sparse sets in D.

Can be used to create fixed-size maps with O(1) insertion, lookup, and removal; and lightning-fast iteration over values that are in the set.

Two variants are available, with almost identical interfaces:
- Static: Implemented using static arrays. Fixed in size.
- Dynamic: Implemented with dynamic arrays using user-defined allocators (see: [memterface](https://code.dlang.org/packages/memterface)). The sparse array is still fixed in size, but the dense array can grow and shrink.

Documentation is provided in the library's source code. Make sure to also read a function's preconditions where applicable.

## Example
```d
import sparse;
import std.stdio: writefln;

void main(){
	StaticSparseSet!(string, 128, 64) mySet; //Can store up to 64 strings, with unique IDs 0–127.
	
	mySet.add(12, "Twelve"); //O(1) element insertion
	mySet.add(7, "Seven");
	mySet.add(49, "Forty-nine");
	foreach(ref element; mySet.denseElements){ //Same speed as a foreach over an array
		writefln("%d: %s", element.ind, element.value);
		//12: Twelve
		//7: Seven
		//49: Forty-nine
		element.value ~= "!!";
	}
	mySet.remove(12); //O(1) element removal
	foreach(element; mySet.denseElementsConst){ //Still the same speed as a foreach over an array!
		writefln("%d: %s", element.ind, element.value);
		//49: Forty-nine!!
		//7: Seven!!
	}
	if(auto valuePtr = 49 in mySet){ //O(1) element look-up (can also be done with `.has()` and then `.get()`/`.read()`)
		assert(*valuePtr == "Forty-nine!!");
	}
	mySet.clear(); //O(1) clearing
}
```
