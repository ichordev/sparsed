# SparseD
An incredibly simple sparse set implemented in D with static arrays. Compatible with BetterC, `@nogc`, and `nothrow`.

Currently, the whole implementation is `nothrow @nogc pure @safe`, although this could change in the future.

Documentation is provided in the library's source code. Make sure to also read a function's preconditions where applicable.

## Example
```d
import sparse;
import std.stdio: writefln;

void main(){
	SparseSet!(string, 128, 64) mySet; //Can store up to 64 strings, with unique IDs 0–127.
	
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
	foreach(element; mySet.denseElementsConst){ //Still the speed as a foreach over an array!
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
