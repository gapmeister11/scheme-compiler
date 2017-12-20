CRAP (Completely RAdical Compiler)
========================

## Overview

CRAP is a compiler which takes a subset of Scheme and produces an executable.

## Features

CRAP supports the following primitive operations:

(= v..2) -> boolean?

v: number?

Returns #t if all v are the same number, #f otherwise.

(eq? a b) -> boolean?

a: any

b: any

Returns #t if a and b refer to the same object, otherwise #f.

(eqv? a b) -> boolean?

a: any

b: any

Same as eq? but treats numbers differently.

(< v..2) -> boolean?

v: number?

Returns #t if the elements of v are in increasing order.

(<= v..2) -> boolean?

v: number?

Returns #t if the elements of v are not in decreasing order.

(> v..2) -> boolean?

v: number?

Returns #t if the elements of v are in decreasing order.

(>= v..2) -> boolean?

v: number?

Returns #t if the elements of v are not in increasing order.

(+ v...) -> number?

v: number?

Returns the sum of all elements of v, or 0 if v is null.

(- v) -> number?

v: number?

Returns the arithmetic inverse of v.

(- v w..1) -> number?

v: number?

w: number?

Returns the difference of v with all elements of w.

(* v...) -> number?

v: number?

Returns the product of all elements of v, or 1 if v is null.

(/ v w..1) -> number?

v: number?

w: number?

Returns v divided by the product of w. If any element of w is 0, raises a runtime error.

(number? c) -> boolean?

c: any

Returns #t if c is an integer, and #f otherwise

(integer? c) -> boolean?

c: any

Same as number?

(call/cc p) -> continuation

p: procedure?

Captures the current continuation as a function and passes it as a value to p.

(car c) -> any

c: cons?

Returns the head of c.

(cdr c) -> any

c: cons?

Returns the tail of c.

(cons a b) -> cons?

a: any

b: any

Allocates and returns a cons cell with a and b as its head and tail, respectively.

(cons? c) -> boolean?

c: any

Returns #t if c is a cons cell, and #f otherwise.

(null? l) -> boolean?

l: any

Returns #t if l is an empty list, #f otherwise.

(list v...) -> cons?

v: any

Allocates and returns a list with v as its elements or '() if v is null.

(void) -> void?

Returns a void value.

(void? v) -> boolean?

v: any

Returns #t if v is void, #f otherwise.

(set! var val) -> void?

var: any

val: any

Mutates var to contain the val.

(procedure? p) -> boolean?

p: any

Returns #t if p is a procedure, and #f otherwise.

(raise e) -> void?

e: any

Raises e as an exception to be caught by a guard statement.

(halt p) -> void?

p: any

Prints p to the console and halts the program.

(print p) -> void?

p: any

Prints p to the console.

(vector v...) -> vector

v: any

Allocates a vector of the appropriate size and fills it with the contents of v.

(make-vector l v) -> vector

l: number?

v: any

Creates a vector of length l and fills each index with v.

(vector-ref v l) -> any

v: vector?

l: number?

Returns the content at the l-th index of v, starting at 0.

(vector-set! v l val) -> void?

v: vector?

l: number?

val: any

Mutates v by placing val at the l-th index, starting at 0.

(and v...) -> boolean?

v: boolean?

Returns #t if v is null or if every member of v is #t, otherwise returns #f.

(or v...) -> boolean?

v: boolean?

Returns #t if at least one member of v is #t, otherwise returns #f.

(not v) -> boolean?

v: boolean?

Returns #t if v is #f, and vice-versa.

(make-hash) -> hash?

Returns a new mutable hash

(hash-set! h k v) -> void?

h: hash?

k: any

v: any

Mutates h by adding (k, v) as a new key-value pair, replacing the previous pair if necessary.

(hash-ref h k) -> any

h: hash?

k: any

Returns the value mapped to k in h. The program terminates if the key does not exist in the hash.

## Runtime Errors

CRAP is smart enough to catch some runtime errors.

Division by Zero: attempting to divide by zero will raise an error.

Memory Usage: heap allocation is capped at 256MiB - going over will result in termination of the program. This value can be adjusted in header.cpp, wherein it is controlled by the memcap compile-time constant. This constant is formatted in bytes, with 0 meaning uncapped. Uncap with caution.

Application of Non-Functions: attempting to apply a non-function value will terminate the program.

Not handled is the arity of functions - some work was made on that front, but it never came to fruition. Also not handled is the checking or printing of hashes.

## Command Line Arguments

The compiler takes several command line arguments. The general form of a call to CRAP is the following:

racket tests.rkt [-g/-O] [-CL/clang++/directory/path] test-name

The -g flag turns on debug symbols.

The -O flag turns on optimization (-O2 clang++ flag). It is mutually exclusive with -g.

The -CL flag is used to point to a specific location for clang++. Note that there are no spaces between the flag and the location, and that the location provided must be to the directory containing clang++, not the path of clang++ itself.

Files to be compiled should be put in the "tests" directory and given the ".scm" extension. Note that the call to the compiler leaves out the extension - calling it on "test-name" will compile "tests/test-name.scm".

## Garbage Collection

Heap allocated data (vectors, cons cells, closures) is handled by the [Boehm GC](https://github.com/ivmai/bdwgc). To that end heap-allocated values are tagged differently than stack-allocated ones, having an extra word of memory in order to keep the pointers clean. The GC also handles the heap cap, with each allocation checking the amount free before continuing.

## Added feature: Mutable hash table

CRAP uses [Nedtries](https://github.com/ned14/nedtries) to implement mutable hash tables, including make-hash, hash-ref, and hash-set!.

## Third-Party Licenses

As CRAP is distributed in source form, the licenses to the third-party libraries used in it can be found in their respective source files, specifically in gc.h and nedtries.h.
The racket compilation programs (cps.rkt, closure-convert.rkt) were taken from the example solutions and are the property of Thomas Gilray and Javran Cheng.

## Other Notes

Tests that begin with "fail-" are tested differently - they are only tested in LLVM and termination is considered a success. This is due to them handling errors that are not present in the Scheme code, such as out of memory exceptions or anything else handled directly in the LLVM.

## Academic Honor Pledge

I, George Petterson, pledge on my honor that I have not given or received any unauthorized assistance on this project.
