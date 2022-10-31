### A Pluto.jl notebook ###
# v0.19.5

using Markdown
using InteractiveUtils

# ╔═╡ 2b7991e8-163a-401b-af26-8ea748fe9a19
using BenchmarkTools

# ╔═╡ bd744128-81e6-429d-aacc-586a1b49375c
using PlutoUI

# ╔═╡ ddcb35db-bc96-46d9-8224-639352d97434
using StaticArrays

# ╔═╡ efa301fa-586d-11ed-2416-631f26422c31
md"""
# Optimizing Serial Code

Chris Rackauckas
September 3rd, 2019

## Introduction

If you prefer, you may follow along with the lecture recordings.

- [Youtube Video Link Part 1](https://youtu.be/M2i7sSRcSIw)
- [Youtube Video Link Part 2](https://youtu.be/10_Ukm9wr9g)

At the center of any fast parallel code is a fast serial code. Parallelism
is made to be a performance multiplier, so if you start from a bad position it
won't ever get much better. Thus the first thing that we need to do is understand
what makes code slow and how to avoid the pitfalls. This discussion of serial
code optimization will also directly motivate why we will be using Julia
throughout this course.

## Mental Model of a Memory

To start optimizing code you need a good mental model of a computer.

### High Level View

At the highest level you have a CPU's core memory which directly accesses a
L1 cache. The L1 cache has the fastest access, so things which will be needed
soon are kept there. However, it is filled from the L2 cache, which itself
is filled from the L3 cache, which is filled from the main memory. This bring
us to the first idea in optimizing code: using things that are already in
a closer cache can help the code run faster because it doesn't have to be
queried for and moved up this chain.

![](https://hackernoon.com/hn-images/1*nT3RAGnOAWmKmvOBnizNtw.png)

When something needs to be pulled directly from main memory this is known as a
*cache miss*. To understand the cost of a cache miss vs standard calculations,
take a look at [this classic chart](http://ithare.com/infographics-operation-costs-in-cpu-clock-cycles/).

(Cache-aware and cache-oblivious algorithms are methods which change their
indexing structure to optimize their use of the cache lines. We will return
to this when talking about performance of linear algebra.)

### Cache Lines and Row/Column-Major

Many algorithms in numerical
linear algebra are designed to minimize cache misses. Because of this chain,
many modern CPUs try to guess what you will want next in your cache. When
dealing with arrays, it will speculate ahead and grab what is known as a *cache
line*: the next chunk in the array. Thus, your algorithms will be faster if
you iterate along the values that it is grabbing.

The values that it grabs are the next values in the contiguous order of the
stored array. There are two common conventions: row major and column major.
Row major means that the linear array of memory is formed by stacking the
rows one after another, while column major puts the column vectors one after
another.

![](https://eli.thegreenplace.net/images/2015/column-major-2D.png)

*Julia, MATLAB, and Fortran are column major*. Python's numpy is row-major.

"""

# ╔═╡ a110d6bb-9753-42c3-9846-5f0ae79281be
A = rand(100,100)

# ╔═╡ 605be721-ea01-447f-ae96-843a963e2594
B = rand(100,100)

# ╔═╡ 33cc0e28-1348-4b13-870a-4ae4bc338f72
C = rand(100,100)

# ╔═╡ f3386ea9-a62d-4926-a5c5-eb6e3d85297f
function inner_rows!(C,A,B)
  for i in 1:100, j in 1:100
    C[i,j] = A[i,j] + B[i,j]
  end
end

# ╔═╡ 9b2384b4-a516-450a-b78c-d32e01634db2
with_terminal() do
	@btime inner_rows!(C,A,B)
end

# ╔═╡ 3f0d5dac-90c1-4f5a-add9-937ce882ebc1
function inner_cols!(C,A,B)
  for j in 1:100, i in 1:100
    C[i,j] = A[i,j] + B[i,j]
  end
end

# ╔═╡ ea2eee7d-c38a-4543-b0d0-e58f8d9e905f
with_terminal() do
	@btime inner_cols!(C,A,B)
end

# ╔═╡ 1c71426a-0b87-4fed-8108-1440f66efb19
md"""
### Lower Level View: The Stack and the Heap

Locally, the stack is composed of a *stack* and a *heap*. The stack requires a
static allocation: it is ordered. Because it's ordered, it is very clear where
things are in the stack, and therefore accesses are very quick (think
instantaneous). However, because this is static, it requires that the size
of the variables is known at compile time (to determine all of the variable
locations). Since that is not possible with all variables, there exists the
heap. The heap is essentially a stack of pointers to objects in memory. When
heap variables are needed, their values are pulled up the cache chain and
accessed.

![](https://bayanbox.ir/view/581244719208138556/virtual-memory.jpg)
![](https://camo.githubusercontent.com/ca96d70d09ce694363e44b93fd975bb3033898c1/687474703a2f2f7475746f7269616c732e6a656e6b6f762e636f6d2f696d616765732f6a6176612d636f6e63757272656e63792f6a6176612d6d656d6f72792d6d6f64656c2d352e706e67)

### Heap Allocations and Speed

Heap allocations are costly because they involve this pointer indirection,
so stack allocation should be done when sensible (it's not helpful for really
large arrays, but for small values like scalars it's essential!)
"""

# ╔═╡ 79bdc48d-d9ba-40ac-8dec-e0e521497596
function inner_alloc!(C,A,B)
  for j in 1:100, i in 1:100
    val = [A[i,j] + B[i,j]]
    C[i,j] = val[1]
  end
end

# ╔═╡ aa2408da-0f3a-403b-b4ea-b4f015d411c9
with_terminal() do 
	@btime inner_alloc!(C,A,B)
end

# ╔═╡ d1c5c846-04ff-4a81-97cd-8d355bfb550b
function inner_noalloc!(C,A,B)
  for j in 1:100, i in 1:100
    val = A[i,j] + B[i,j]
    C[i,j] = val[1]
  end
end

# ╔═╡ c7e5e6b2-41f8-44bb-aec3-48f19e874923
with_terminal() do 
	@btime inner_noalloc!(C,A,B)
end

# ╔═╡ 0449716f-2535-4f3d-913d-a63b17031842
md"""
Why does the array here get heap-allocated? It isn't able to prove/guarantee
at compile-time that the array's size will always be a given value, and thus
it allocates it to the heap. `@btime` tells us this allocation occurred and
shows us the total heap memory that was taken. Meanwhile, the size of a Float64
number is known at compile-time (64-bits), and so this is stored onto the stack
and given a specific location that the compiler will be able to directly
address.

Note that one can use the StaticArrays.jl library to get statically-sized arrays
and thus arrays which are stack-allocated:

"""

# ╔═╡ 2f204dd2-fdcf-48ac-9cdf-913df815f828
function static_inner_alloc!(C,A,B)
  for j in 1:100, i in 1:100
    val = @SVector [A[i,j] + B[i,j]]
    C[i,j] = val[1]
  end
end

# ╔═╡ 18d701d1-9c05-4d7b-9a07-0d99601d99fd
with_terminal() do
	@btime static_inner_alloc!(C,A,B)
end

# ╔═╡ 86b73ddb-3d6a-484c-b732-4a1857a350ba
md"""
### Mutation to Avoid Heap Allocations

Many times you do need to write into an array, so how can you write into an
array without performing a heap allocation? The answer is mutation. Mutation
is changing the values of an already existing array. In that case, no free
memory has to be found to put the array (and no memory has to be freed by
the garbage collector).

In Julia, functions which mutate the first value are conventionally noted by
a `!`. See the difference between these two equivalent functions:

"""

# ╔═╡ 7a3c4a03-9cf7-443f-b75a-0c40fbb14022
function inner_noalloc_no_heap!(C,A,B)
  for j in 1:100, i in 1:100
    val = A[i,j] + B[i,j]
    C[i,j] = val[1]
  end
end

# ╔═╡ e3fcc8ea-bce3-4d27-a288-e40ff8a05d46
with_terminal() do
	@btime inner_noalloc_no_heap!(C,A,B)
end

# ╔═╡ d7cc930b-9029-401a-825c-ed50607c20bc
function inner_alloc_no_heap(A,B)
  C = similar(A)
  for j in 1:100, i in 1:100
    val = A[i,j] + B[i,j]
    C[i,j] = val[1]
  end
end

# ╔═╡ 53231029-2cda-47b5-a81c-8b34d044752e
with_terminal() do
	@btime inner_alloc_no_heap(A,B)
end

# ╔═╡ 61d7e24b-4fa0-4938-a718-b1479fe0411a
md"""
To use this algorithm effectively, the `!` algorithm assumes that the caller
already has allocated the output array to put as the output argument. If that
is not true, then one would need to manually allocate. The goal of that interface
is to give the caller control over the allocations to allow them to manually
reduce the total number of heap allocations and thus increase the speed.

### Julia's Broadcasting Mechanism

Wouldn't it be nice to not have to write the loop there? In many high level
languages this is simply called *vectorization*. In Julia, we will call it
*array vectorization* to distinguish it from the *SIMD vectorization* which
is common in lower level languages like C, Fortran, and Julia.

In Julia, if you use `.` on an operator it will transform it to the broadcasted
form. Broadcast is *lazy*: it will build up an entire `.`'d expression and then
call `broadcast!` on composed expression. This is customizable and
[documented in detail](https://docs.julialang.org/en/v1/manual/interfaces/#man-interfaces-broadcasting-1).
However, to a first approximation we can think of the broadcast mechanism as a
mechanism for building *fused expressions*. For example, the Julia code:

"""

# ╔═╡ 8257f32f-c5a2-49da-9c4f-e474461e065e
A .+ B .+ C;

# ╔═╡ a96e3d71-c819-4b2d-94b5-e37f168b1df4
md"""
under the hood lowers to something like:
"""

# ╔═╡ 7dcfd90b-8b25-4638-aaa2-7a5f51185ddd
map((a,b,c)->a+b+c,A,B,C);

# ╔═╡ 488a7fcd-ffec-41f9-9990-c0a3fc4ca563
md"""
where `map` is a function that just loops over the values element-wise.

**Take a quick second to think about why loop fusion may be an optimization.**

This about what would happen if you did not fuse the operations. We can write
that out as:

"""

# ╔═╡ 4b25018a-1867-4376-8483-9c1bb08bab21
begin
	tmp = A .+ B
	tmp .+ C
end;

# ╔═╡ 2949d77f-f378-47b1-9250-23fd322655a7
md"""
Notice that if we did not fuse the expressions, we would need some place to put
the result of `A .+ B`, and that would have to be an array, which means it would
cause a heap allocation. Thus broadcast fusion eliminates the *temporary variable*
(colloquially called just a *temporary*).

"""

# ╔═╡ 5104f912-c852-46af-a1af-db150a7fee36
function unfused(A,B,C)
  tmp = A .+ B
  tmp .+ C
end

# ╔═╡ 90184540-d6d3-4501-894c-85cf03132117
with_terminal() do
	@btime unfused(A,B,C);
end

# ╔═╡ 98256241-901e-4ae5-822e-d6f4e9990425
fused(A,B,C) = A .+ B .+ C

# ╔═╡ feb03b49-9a23-4e52-91f4-c00c60fd2397
with_terminal() do
	@btime fused(A,B,C);
end

# ╔═╡ 9067d79f-f890-430d-afac-242538c2c110
md"""
Note that we can also fuse the output by using `.=`. This is essentially the
vectorized version of a `!` function:
"""

# ╔═╡ 708212da-88c0-4bda-868a-2f46f605e0c8
D = similar(A)

# ╔═╡ 2be90cc4-d3f6-418f-8cac-5aa273de749d
fused!(D,A,B,C) = (D .= A .+ B .+ C)

# ╔═╡ fefacbad-7b39-4569-aab5-186c5f4fa0a3
with_terminal() do
	@btime fused!(D,A,B,C);
end

# ╔═╡ 09331f78-57f4-4a9e-82ff-b4ff3af1f77f
md"""
### Note on Broadcasting Function Calls

Julia allows for broadcasting the call `()` operator as well. `.()` will call
the function element-wise on all arguments, so `sin.(A)` will be the elementwise
sine function. This will fuse Julia like the other operators.

### Note on Vectorization and Speed

In articles on MATLAB, Python, R, etc., this is where you will be told to
vectorize your code. Notice from above that this isn't a performance difference
between writing loops and using vectorized broadcasts. This is not abnormal!
The reason why you are told to vectorize code in these other languages is because
they have a high per-operation overhead (which will be discussed further down).
This means that every call, like `+`, is costly in these languages. To get around
this issue and make the language usable, someone wrote and compiled the loop
for the C/Fortran function that does the broadcasted form (see numpy's Github repo).
Thus `A .+ B`'s MATLAB/Python/R equivalents are calling a single C function
to generally avoid the cost of function calls and thus are faster.

But this is not an intrinsic property of vectorization. Vectorization isn't
"fast" in these languages, it's just close to the correct speed. The reason
vectorization is recommended is because looping is slow in these languages.
Because looping isn't slow in Julia (or C, C++, Fortran, etc.), loops and vectorization
generally have the same speed. So use the one that works best for your code
without a care about performance.

(As a small side effect, these high level languages tend to allocate a lot of
temporary variables since the individual C kernels are written for specific
numbers of inputs and thus don't naturally fuse. Julia's broadcast mechanism
is just generating and JIT compiling Julia functions on the fly, and thus it
can accommodate the combinatorial explosion in the amount of choices just by
only compiling the combinations that are necessary for a specific code)

### Heap Allocations from Slicing

It's important to note that slices in Julia produce copies instead of views.
Thus for example:

"""

# ╔═╡ bd0d2805-3874-4d68-9d4f-a205d77df2c7
A[50,50]

# ╔═╡ 78ee6c1c-2ee2-438e-99f2-e18707ba9e42
md"""
allocates a new output. This is for safety, since if it pointed to the same
array then writing to it would change the original array. We can demonstrate
this by asking for a *view* instead of a copy.


"""

# ╔═╡ b234f7a5-8a2a-41f5-8660-97275aefa10d
with_terminal() do
	@show A[1]
	E = @view A[1:5,1:5]
	E[1] = 2.0
	@show A[1]
	
end

# ╔═╡ 92de6651-aa45-4280-9b73-413db3a95e11
md"""
However, this means that `@view A[1:5,1:5]` did not allocate an array (it does
allocate a pointer if the escape analysis is unable to prove that it can be
elided. This means that in small loops there will be no allocation, while if
the view is returned from a function for example it will allocate the pointer,
~80 bytes, but not the memory of the array. This means that it is O(1) in cost
but with a relatively small constant).

### Asymptotic Cost of Heap Allocations

Heap allocations have to locate and prepare a space in RAM that is proportional
to the amount of memory that is calculated, which means that the cost of a heap
allocation for an array is O(n), with a large constant. As RAM begins to fill
up, this cost dramatically increases. If you run out of RAM, your computer
may begin to use *swap*, which is essentially RAM simulated on your hard drive.
Generally when you hit swap your performance is so dead that you may think that
your computation froze, but if you check your resource use you will notice that
it's actually just filled the RAM and starting to use the swap.

But think of it as O(n) with a large constant factor. This means that for
operations which only touch the data once, heap allocations can dominate the
computational cost:
"""

# ╔═╡ 8adac851-75b3-49c4-adf7-4c0d89140f87
md"""
However, when the computation takes O(n^3), like in matrix multiplications,
the high constant factor only comes into play when the matrices are sufficiently
small:
"""

# ╔═╡ 1720fa35-d05e-40e1-9640-668d99671c0d
md"..."

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
BenchmarkTools = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"

[compat]
BenchmarkTools = "~1.3.1"
PlutoUI = "~0.7.48"
StaticArrays = "~1.5.9"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.8.2"
manifest_format = "2.0"
project_hash = "ff4df2c8ffb6c0c39d2a492098e4dda216df1078"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "8eaf9f1b4921132a4cff3f36a1d9ba923b14a481"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.1.4"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.BenchmarkTools]]
deps = ["JSON", "Logging", "Printf", "Profile", "Statistics", "UUIDs"]
git-tree-sha1 = "4c10eee4af024676200bc7752e536f858c6b8f93"
uuid = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
version = "1.3.1"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "eb7f0f8307f71fac7c606984ea5fb2817275d6e4"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.4"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "0.5.2+0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[deps.Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "8d511d5b81240fc8e6802386302675bdf47737b9"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.4"

[[deps.HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "c47c5fa4c5308f27ccaac35504858d8914e102f9"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.4"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "f7be53659ab06ddc986428d3a9dcc95f6fa6705a"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.2"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "3c837543ddb02250ef42f4738347454f95079d4e"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.3"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.3"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "7.84.0+0"

[[deps.LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.10.2+0"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.LinearAlgebra]]
deps = ["Libdl", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.MIMEs]]
git-tree-sha1 = "65f28ad4b594aebe22157d6fac869786a255b7eb"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "0.1.4"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.0+0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2022.2.1"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.20+0"

[[deps.Parsers]]
deps = ["Dates"]
git-tree-sha1 = "6c01a9b494f6d2a9fc180a08b182fcb06f0958a0"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.4.2"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.8.0"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "efc140104e6d0ae3e7e30d56c98c4a927154d684"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.48"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.Profile]]
deps = ["Printf"]
uuid = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "Random", "StaticArraysCore", "Statistics"]
git-tree-sha1 = "f86b3a049e5d05227b10e15dbb315c5b90f14988"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.5.9"

[[deps.StaticArraysCore]]
git-tree-sha1 = "6b7ba252635a5eff6a0b0664a41ee140a1c9e72a"
uuid = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
version = "1.4.0"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.0"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.1"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.Tricks]]
git-tree-sha1 = "6bac775f2d42a611cdfcd1fb217ee719630c4175"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.6"

[[deps.URIs]]
git-tree-sha1 = "e59ecc5a41b000fa94423a578d29290c7266fc10"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.4.0"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.12+3"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl", "OpenBLAS_jll"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.1.1+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.48.0+0"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+0"
"""

# ╔═╡ Cell order:
# ╟─efa301fa-586d-11ed-2416-631f26422c31
# ╠═a110d6bb-9753-42c3-9846-5f0ae79281be
# ╠═605be721-ea01-447f-ae96-843a963e2594
# ╠═33cc0e28-1348-4b13-870a-4ae4bc338f72
# ╠═2b7991e8-163a-401b-af26-8ea748fe9a19
# ╠═f3386ea9-a62d-4926-a5c5-eb6e3d85297f
# ╠═bd744128-81e6-429d-aacc-586a1b49375c
# ╠═9b2384b4-a516-450a-b78c-d32e01634db2
# ╠═3f0d5dac-90c1-4f5a-add9-937ce882ebc1
# ╠═ea2eee7d-c38a-4543-b0d0-e58f8d9e905f
# ╟─1c71426a-0b87-4fed-8108-1440f66efb19
# ╠═79bdc48d-d9ba-40ac-8dec-e0e521497596
# ╠═aa2408da-0f3a-403b-b4ea-b4f015d411c9
# ╠═d1c5c846-04ff-4a81-97cd-8d355bfb550b
# ╠═c7e5e6b2-41f8-44bb-aec3-48f19e874923
# ╟─0449716f-2535-4f3d-913d-a63b17031842
# ╠═ddcb35db-bc96-46d9-8224-639352d97434
# ╠═2f204dd2-fdcf-48ac-9cdf-913df815f828
# ╠═18d701d1-9c05-4d7b-9a07-0d99601d99fd
# ╟─86b73ddb-3d6a-484c-b732-4a1857a350ba
# ╠═7a3c4a03-9cf7-443f-b75a-0c40fbb14022
# ╠═e3fcc8ea-bce3-4d27-a288-e40ff8a05d46
# ╠═d7cc930b-9029-401a-825c-ed50607c20bc
# ╠═53231029-2cda-47b5-a81c-8b34d044752e
# ╟─61d7e24b-4fa0-4938-a718-b1479fe0411a
# ╠═8257f32f-c5a2-49da-9c4f-e474461e065e
# ╟─a96e3d71-c819-4b2d-94b5-e37f168b1df4
# ╠═7dcfd90b-8b25-4638-aaa2-7a5f51185ddd
# ╟─488a7fcd-ffec-41f9-9990-c0a3fc4ca563
# ╠═4b25018a-1867-4376-8483-9c1bb08bab21
# ╟─2949d77f-f378-47b1-9250-23fd322655a7
# ╠═5104f912-c852-46af-a1af-db150a7fee36
# ╠═90184540-d6d3-4501-894c-85cf03132117
# ╠═98256241-901e-4ae5-822e-d6f4e9990425
# ╠═feb03b49-9a23-4e52-91f4-c00c60fd2397
# ╟─9067d79f-f890-430d-afac-242538c2c110
# ╠═708212da-88c0-4bda-868a-2f46f605e0c8
# ╠═2be90cc4-d3f6-418f-8cac-5aa273de749d
# ╠═fefacbad-7b39-4569-aab5-186c5f4fa0a3
# ╟─09331f78-57f4-4a9e-82ff-b4ff3af1f77f
# ╠═bd0d2805-3874-4d68-9d4f-a205d77df2c7
# ╟─78ee6c1c-2ee2-438e-99f2-e18707ba9e42
# ╠═b234f7a5-8a2a-41f5-8660-97275aefa10d
# ╟─92de6651-aa45-4280-9b73-413db3a95e11
# ╟─8adac851-75b3-49c4-adf7-4c0d89140f87
# ╟─1720fa35-d05e-40e1-9640-668d99671c0d
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
