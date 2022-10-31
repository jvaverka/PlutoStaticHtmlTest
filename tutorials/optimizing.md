~~~
<!-- PlutoStaticHTML.Begin -->
<!--
    # This information is used for caching.
    [PlutoStaticHTML.State]
    input_sha = "f19a9f9f10f0e6f7893c3f07de3b54e21835db0a6850122280d34a4401b59405"
    julia_version = "1.8.2"
-->

<div class="markdown"><h1>Optimizing Serial Code</h1>
<p>Chris Rackauckas September 3rd, 2019</p>
<h2>Introduction</h2>
<p>If you prefer, you may follow along with the lecture recordings.</p>
<ul>
<li><p><a href="https://youtu.be/M2i7sSRcSIw">Youtube Video Link Part 1</a></p>
</li>
<li><p><a href="https://youtu.be/10_Ukm9wr9g">Youtube Video Link Part 2</a></p>
</li>
</ul>
<p>At the center of any fast parallel code is a fast serial code. Parallelism is made to be a performance multiplier, so if you start from a bad position it won&#39;t ever get much better. Thus the first thing that we need to do is understand what makes code slow and how to avoid the pitfalls. This discussion of serial code optimization will also directly motivate why we will be using Julia throughout this course.</p>
<h2>Mental Model of a Memory</h2>
<p>To start optimizing code you need a good mental model of a computer.</p>
<h3>High Level View</h3>
<p>At the highest level you have a CPU&#39;s core memory which directly accesses a L1 cache. The L1 cache has the fastest access, so things which will be needed soon are kept there. However, it is filled from the L2 cache, which itself is filled from the L3 cache, which is filled from the main memory. This bring us to the first idea in optimizing code: using things that are already in a closer cache can help the code run faster because it doesn&#39;t have to be queried for and moved up this chain.</p>
<p><img src="https://hackernoon.com/hn-images/1*nT3RAGnOAWmKmvOBnizNtw.png" alt="" /></p>
<p>When something needs to be pulled directly from main memory this is known as a <em>cache miss</em>. To understand the cost of a cache miss vs standard calculations, take a look at <a href="http://ithare.com/infographics-operation-costs-in-cpu-clock-cycles/">this classic chart</a>.</p>
<p>&#40;Cache-aware and cache-oblivious algorithms are methods which change their indexing structure to optimize their use of the cache lines. We will return to this when talking about performance of linear algebra.&#41;</p>
<h3>Cache Lines and Row/Column-Major</h3>
<p>Many algorithms in numerical linear algebra are designed to minimize cache misses. Because of this chain, many modern CPUs try to guess what you will want next in your cache. When dealing with arrays, it will speculate ahead and grab what is known as a <em>cache line</em>: the next chunk in the array. Thus, your algorithms will be faster if you iterate along the values that it is grabbing.</p>
<p>The values that it grabs are the next values in the contiguous order of the stored array. There are two common conventions: row major and column major. Row major means that the linear array of memory is formed by stacking the rows one after another, while column major puts the column vectors one after another.</p>
<p><img src="https://eli.thegreenplace.net/images/2015/column-major-2D.png" alt="" /></p>
<p><em>Julia, MATLAB, and Fortran are column major</em>. Python&#39;s numpy is row-major.</p>
</div>

<pre class='language-julia'><code class='language-julia'>A = rand(100,100)</code></pre>
<pre id='var-A' class='code-output documenter-example-output'>100×100 Matrix{Float64}:
 0.695207  0.762065   0.63296    0.280616   …  0.632753   0.475399     0.384153
 0.325112  0.991844   0.239715   0.0516867     0.801208   0.858632     0.26418
 0.495676  0.428267   0.050936   0.129378      0.301442   0.376702     0.213312
 0.567774  0.0301164  0.530402   0.864369      0.334178   0.691637     0.138706
 0.796557  0.628679   0.0292913  0.610021      0.351843   0.315219     0.786565
 0.148813  0.092304   0.669958   0.0520742  …  0.590546   0.474505     0.675142
 0.633834  0.0598601  0.539061   0.597527      0.0785462  0.983387     0.150333
 ⋮                                          ⋱                          
 0.163257  0.0970967  0.37058    0.275312      0.582144   0.684614     0.160318
 0.802099  0.988474   0.768783   0.10869    …  0.211636   0.189878     0.639509
 0.686327  0.18355    0.811451   0.18708       0.745383   0.000360434  0.995333
 0.976863  0.178304   0.580433   0.317149      0.391116   0.325836     0.57896
 0.186252  0.342176   0.564014   0.994933      0.0173983  0.991217     0.603537
 0.284778  0.177411   0.989444   0.550422      0.510409   0.412458     0.0853041</pre>

<pre class='language-julia'><code class='language-julia'>B = rand(100,100)</code></pre>
<pre id='var-B' class='code-output documenter-example-output'>100×100 Matrix{Float64}:
 0.00134059  0.404914   0.397329    0.81653   …  0.785514  0.245785   0.0272313
 0.691313    0.300756   0.768037    0.280627     0.818389  0.929875   0.425245
 0.981162    0.731216   0.341326    0.145315     0.775785  0.924353   0.75196
 0.238268    0.950163   0.00566807  0.258604     0.310735  0.576941   0.501183
 0.644922    0.0976872  0.466938    0.810551     0.271878  0.568473   0.945559
 0.971149    0.896583   0.850988    0.850342  …  0.956246  0.0688988  0.603778
 0.848284    0.617414   0.962944    0.260881     0.582787  0.269916   0.196316
 ⋮                                            ⋱                       
 0.699581    0.736503   0.0598195   0.226966     0.745792  0.870333   0.61186
 0.0783785   0.0971109  0.458778    0.390599  …  0.181367  0.716426   0.86867
 0.0949049   0.150486   0.747729    0.497171     0.19299   0.514159   0.409362
 0.414009    0.431571   0.186791    0.800654     0.765178  0.436461   0.598326
 0.0258815   0.101907   0.477122    0.494937     0.162349  0.614848   0.863104
 0.455916    0.237641   0.652602    0.681573     0.894634  0.505447   0.0376122</pre>

<pre class='language-julia'><code class='language-julia'>C = rand(100,100)</code></pre>
<pre id='var-C' class='code-output documenter-example-output'>100×100 Matrix{Float64}:
 0.437736   0.763495   0.865073   0.174821   …  0.470127   0.546853   0.561133
 0.464247   0.0928707  0.668393   0.813132      0.383739   0.0468084  0.334291
 0.964027   0.0301059  0.150075   0.0383602     0.841276   0.0708062  0.597768
 0.4151     0.892877   0.773096   0.133253      0.776238   0.702613   0.613848
 0.271843   0.910142   0.600908   0.245391      0.582447   0.811867   0.608082
 0.284947   0.603483   0.0133781  0.851065   …  0.488526   0.335032   0.853303
 0.318427   0.654258   0.895994   0.977302      0.455587   0.928039   0.145121
 ⋮                                           ⋱                        
 0.23111    0.358809   0.853628   0.796479      0.528343   0.565375   0.445657
 0.0532888  0.308125   0.636317   0.450428   …  0.0098036  0.396439   0.795003
 0.566238   0.897803   0.312184   0.0855161     0.421621   0.997624   0.579094
 0.973336   0.184534   0.213591   0.422076      0.104829   0.541635   0.564384
 0.538133   0.0717455  0.396185   0.804496      0.632194   0.183693   0.820741
 0.538241   0.332613   0.794942   0.32264       0.418498   0.79146    0.0440692</pre>

<pre class='language-julia'><code class='language-julia'>using BenchmarkTools</code></pre>


<pre class='language-julia'><code class='language-julia'>function inner_rows!(C,A,B)
  for i in 1:100, j in 1:100
    C[i,j] = A[i,j] + B[i,j]
  end
end</code></pre>
<pre id='var-inner_rows!' class='code-output documenter-example-output'>inner_rows! (generic function with 1 method)</pre>

<pre class='language-julia'><code class='language-julia'>using PlutoUI</code></pre>


<pre class='language-julia'><code class='language-julia'>with_terminal() do
    @btime inner_rows!(C,A,B)
end</code></pre>
<pre id="plutouiterminal">
  13.700 μs (0 allocations: 0 bytes)
</pre>


<pre class='language-julia'><code class='language-julia'>function inner_cols!(C,A,B)
  for j in 1:100, i in 1:100
    C[i,j] = A[i,j] + B[i,j]
  end
end</code></pre>
<pre id='var-inner_cols!' class='code-output documenter-example-output'>inner_cols! (generic function with 1 method)</pre>

<pre class='language-julia'><code class='language-julia'>with_terminal() do
    @btime inner_cols!(C,A,B)
end</code></pre>
<pre id="plutouiterminal">
  6.920 μs (0 allocations: 0 bytes)
</pre>



<div class="markdown"><h3>Lower Level View: The Stack and the Heap</h3>
<p>Locally, the stack is composed of a <em>stack</em> and a <em>heap</em>. The stack requires a static allocation: it is ordered. Because it&#39;s ordered, it is very clear where things are in the stack, and therefore accesses are very quick &#40;think instantaneous&#41;. However, because this is static, it requires that the size of the variables is known at compile time &#40;to determine all of the variable locations&#41;. Since that is not possible with all variables, there exists the heap. The heap is essentially a stack of pointers to objects in memory. When heap variables are needed, their values are pulled up the cache chain and accessed.</p>
<p><img src="https://bayanbox.ir/view/581244719208138556/virtual-memory.jpg" alt="" /> <img src="https://camo.githubusercontent.com/ca96d70d09ce694363e44b93fd975bb3033898c1/687474703a2f2f7475746f7269616c732e6a656e6b6f762e636f6d2f696d616765732f6a6176612d636f6e63757272656e63792f6a6176612d6d656d6f72792d6d6f64656c2d352e706e67" alt="" /></p>
<h3>Heap Allocations and Speed</h3>
<p>Heap allocations are costly because they involve this pointer indirection, so stack allocation should be done when sensible &#40;it&#39;s not helpful for really large arrays, but for small values like scalars it&#39;s essential&#33;&#41;</p>
</div>

<pre class='language-julia'><code class='language-julia'>function inner_alloc!(C,A,B)
  for j in 1:100, i in 1:100
    val = [A[i,j] + B[i,j]]
    C[i,j] = val[1]
  end
end</code></pre>
<pre id='var-inner_alloc!' class='code-output documenter-example-output'>inner_alloc! (generic function with 1 method)</pre>

<pre class='language-julia'><code class='language-julia'>with_terminal() do 
    @btime inner_alloc!(C,A,B)
end</code></pre>
<pre id="plutouiterminal">
  295.900 μs (10000 allocations: 625.00 KiB)
</pre>


<pre class='language-julia'><code class='language-julia'>function inner_noalloc!(C,A,B)
  for j in 1:100, i in 1:100
    val = A[i,j] + B[i,j]
    C[i,j] = val[1]
  end
end</code></pre>
<pre id='var-inner_noalloc!' class='code-output documenter-example-output'>inner_noalloc! (generic function with 1 method)</pre>

<pre class='language-julia'><code class='language-julia'>with_terminal() do 
    @btime inner_noalloc!(C,A,B)
end</code></pre>
<pre id="plutouiterminal">
  8.333 μs (0 allocations: 0 bytes)
</pre>



<div class="markdown"><p>Why does the array here get heap-allocated? It isn&#39;t able to prove/guarantee at compile-time that the array&#39;s size will always be a given value, and thus it allocates it to the heap. <code>@btime</code> tells us this allocation occurred and shows us the total heap memory that was taken. Meanwhile, the size of a Float64 number is known at compile-time &#40;64-bits&#41;, and so this is stored onto the stack and given a specific location that the compiler will be able to directly address.</p>
<p>Note that one can use the StaticArrays.jl library to get statically-sized arrays and thus arrays which are stack-allocated:</p>
</div>

<pre class='language-julia'><code class='language-julia'>using StaticArrays</code></pre>


<pre class='language-julia'><code class='language-julia'>function static_inner_alloc!(C,A,B)
  for j in 1:100, i in 1:100
    val = @SVector [A[i,j] + B[i,j]]
    C[i,j] = val[1]
  end
end</code></pre>
<pre id='var-static_inner_alloc!' class='code-output documenter-example-output'>static_inner_alloc! (generic function with 1 method)</pre>

<pre class='language-julia'><code class='language-julia'>with_terminal() do
    @btime static_inner_alloc!(C,A,B)
end</code></pre>
<pre id="plutouiterminal">
  8.333 μs (0 allocations: 0 bytes)
</pre>



<div class="markdown"><h3>Mutation to Avoid Heap Allocations</h3>
<p>Many times you do need to write into an array, so how can you write into an array without performing a heap allocation? The answer is mutation. Mutation is changing the values of an already existing array. In that case, no free memory has to be found to put the array &#40;and no memory has to be freed by the garbage collector&#41;.</p>
<p>In Julia, functions which mutate the first value are conventionally noted by a <code>&#33;</code>. See the difference between these two equivalent functions:</p>
</div>

<pre class='language-julia'><code class='language-julia'>function inner_noalloc_no_heap!(C,A,B)
  for j in 1:100, i in 1:100
    val = A[i,j] + B[i,j]
    C[i,j] = val[1]
  end
end</code></pre>
<pre id='var-inner_noalloc_no_heap!' class='code-output documenter-example-output'>inner_noalloc_no_heap! (generic function with 1 method)</pre>

<pre class='language-julia'><code class='language-julia'>with_terminal() do
    @btime inner_noalloc_no_heap!(C,A,B)
end</code></pre>
<pre id="plutouiterminal">
  8.500 μs (0 allocations: 0 bytes)
</pre>


<pre class='language-julia'><code class='language-julia'>function inner_alloc_no_heap(A,B)
  C = similar(A)
  for j in 1:100, i in 1:100
    val = A[i,j] + B[i,j]
    C[i,j] = val[1]
  end
end</code></pre>
<pre id='var-inner_alloc_no_heap' class='code-output documenter-example-output'>inner_alloc_no_heap (generic function with 1 method)</pre>

<pre class='language-julia'><code class='language-julia'>with_terminal() do
    @btime inner_alloc_no_heap(A,B)
end</code></pre>
<pre id="plutouiterminal">
  10.400 μs (2 allocations: 78.17 KiB)
</pre>



<div class="markdown"><p>To use this algorithm effectively, the <code>&#33;</code> algorithm assumes that the caller already has allocated the output array to put as the output argument. If that is not true, then one would need to manually allocate. The goal of that interface is to give the caller control over the allocations to allow them to manually reduce the total number of heap allocations and thus increase the speed.</p>
<h3>Julia&#39;s Broadcasting Mechanism</h3>
<p>Wouldn&#39;t it be nice to not have to write the loop there? In many high level languages this is simply called <em>vectorization</em>. In Julia, we will call it <em>array vectorization</em> to distinguish it from the <em>SIMD vectorization</em> which is common in lower level languages like C, Fortran, and Julia.</p>
<p>In Julia, if you use <code>.</code> on an operator it will transform it to the broadcasted form. Broadcast is <em>lazy</em>: it will build up an entire <code>.</code>&#39;d expression and then call <code>broadcast&#33;</code> on composed expression. This is customizable and <a href="https://docs.julialang.org/en/v1/manual/interfaces/#man-interfaces-broadcasting-1">documented in detail</a>. However, to a first approximation we can think of the broadcast mechanism as a mechanism for building <em>fused expressions</em>. For example, the Julia code:</p>
</div>

<pre class='language-julia'><code class='language-julia'>A .+ B .+ C;</code></pre>



<div class="markdown"><p>under the hood lowers to something like:</p>
</div>

<pre class='language-julia'><code class='language-julia'>map((a,b,c)-&gt;a+b+c,A,B,C);</code></pre>



<div class="markdown"><p>where <code>map</code> is a function that just loops over the values element-wise.</p>
<p><strong>Take a quick second to think about why loop fusion may be an optimization.</strong></p>
<p>This about what would happen if you did not fuse the operations. We can write that out as:</p>
</div>

<pre class='language-julia'><code class='language-julia'>begin
    tmp = A .+ B
    tmp .+ C
end;</code></pre>



<div class="markdown"><p>Notice that if we did not fuse the expressions, we would need some place to put the result of <code>A .&#43; B</code>, and that would have to be an array, which means it would cause a heap allocation. Thus broadcast fusion eliminates the <em>temporary variable</em> &#40;colloquially called just a <em>temporary</em>&#41;.</p>
</div>

<pre class='language-julia'><code class='language-julia'>function unfused(A,B,C)
  tmp = A .+ B
  tmp .+ C
end</code></pre>
<pre id='var-unfused' class='code-output documenter-example-output'>unfused (generic function with 1 method)</pre>

<pre class='language-julia'><code class='language-julia'>with_terminal() do
    @btime unfused(A,B,C);
end</code></pre>
<pre id="plutouiterminal">
  9.200 μs (4 allocations: 156.34 KiB)
</pre>


<pre class='language-julia'><code class='language-julia'>fused(A,B,C) = A .+ B .+ C</code></pre>
<pre id='var-fused' class='code-output documenter-example-output'>fused (generic function with 1 method)</pre>

<pre class='language-julia'><code class='language-julia'>with_terminal() do
    @btime fused(A,B,C);
end</code></pre>
<pre id="plutouiterminal">
  5.680 μs (2 allocations: 78.17 KiB)
</pre>



<div class="markdown"><p>Note that we can also fuse the output by using <code>.&#61;</code>. This is essentially the vectorized version of a <code>&#33;</code> function:</p>
</div>

<pre class='language-julia'><code class='language-julia'>D = similar(A)</code></pre>
<pre id='var-D' class='code-output documenter-example-output'>100×100 Matrix{Float64}:
 4.02512e-316  4.02515e-316  4.02518e-316  …  1.64392   2.22928  2.04215  1.75489
 0.0           8.48798e-314  0.0              0.395569  2.57497  1.16102  0.932231
 6.94978e-310  2.64771       4.02519e-316     1.64907   3.26319  3.18227  0.304017
 4.01821e-316  1.92084       8.48798e-314     3.10132   1.78805  2.13249  0.800053
 0.0           0.523273      4.0252e-316      1.02523   3.39154  1.65649  2.01986
 0.0           2.70221       0.0           …  3.27451   2.07415  2.66612  2.97952
 0.817235      1.27068       2.10232          1.34003   1.90131  3.64286  2.57743
 ⋮                                         ⋱                              
 0.0           1.061e-313    0.656982         3.4957    1.42305  3.31092  0.840372
 0.0           0.0           2.29047       …  2.86621   3.76342  2.57364  0.897461
 8.59617e-317  0.0           3.60739e-313     2.3171    3.02237  1.65774  2.30598
 0.0           0.0           0.0              3.09288   1.68832  1.78381  3.21854
 4.02514e-316  8.59642e-317  0.0              1.69412   3.08656  1.86279  2.30359
 0.0           0.0           0.0              1.90709   2.03762  2.19314  1.72425</pre>

<pre class='language-julia'><code class='language-julia'>fused!(D,A,B,C) = (D .= A .+ B .+ C)</code></pre>
<pre id='var-fused!' class='code-output documenter-example-output'>fused! (generic function with 1 method)</pre>

<pre class='language-julia'><code class='language-julia'>with_terminal() do
    @btime fused!(D,A,B,C);
end</code></pre>
<pre id="plutouiterminal">
  4.743 μs (0 allocations: 0 bytes)
</pre>



<div class="markdown"><h3>Note on Broadcasting Function Calls</h3>
<p>Julia allows for broadcasting the call <code>&#40;&#41;</code> operator as well. <code>.&#40;&#41;</code> will call the function element-wise on all arguments, so <code>sin.&#40;A&#41;</code> will be the elementwise sine function. This will fuse Julia like the other operators.</p>
<h3>Note on Vectorization and Speed</h3>
<p>In articles on MATLAB, Python, R, etc., this is where you will be told to vectorize your code. Notice from above that this isn&#39;t a performance difference between writing loops and using vectorized broadcasts. This is not abnormal&#33; The reason why you are told to vectorize code in these other languages is because they have a high per-operation overhead &#40;which will be discussed further down&#41;. This means that every call, like <code>&#43;</code>, is costly in these languages. To get around this issue and make the language usable, someone wrote and compiled the loop for the C/Fortran function that does the broadcasted form &#40;see numpy&#39;s Github repo&#41;. Thus <code>A .&#43; B</code>&#39;s MATLAB/Python/R equivalents are calling a single C function to generally avoid the cost of function calls and thus are faster.</p>
<p>But this is not an intrinsic property of vectorization. Vectorization isn&#39;t &quot;fast&quot; in these languages, it&#39;s just close to the correct speed. The reason vectorization is recommended is because looping is slow in these languages. Because looping isn&#39;t slow in Julia &#40;or C, C&#43;&#43;, Fortran, etc.&#41;, loops and vectorization generally have the same speed. So use the one that works best for your code without a care about performance.</p>
<p>&#40;As a small side effect, these high level languages tend to allocate a lot of temporary variables since the individual C kernels are written for specific numbers of inputs and thus don&#39;t naturally fuse. Julia&#39;s broadcast mechanism is just generating and JIT compiling Julia functions on the fly, and thus it can accommodate the combinatorial explosion in the amount of choices just by only compiling the combinations that are necessary for a specific code&#41;</p>
<h3>Heap Allocations from Slicing</h3>
<p>It&#39;s important to note that slices in Julia produce copies instead of views. Thus for example:</p>
</div>

<pre class='language-julia'><code class='language-julia'>A[50,50]</code></pre>
<pre id='var-hash888489' class='code-output documenter-example-output'>0.12497457124954758</pre>


<div class="markdown"><p>allocates a new output. This is for safety, since if it pointed to the same array then writing to it would change the original array. We can demonstrate this by asking for a <em>view</em> instead of a copy.</p>
</div>

<pre class='language-julia'><code class='language-julia'>with_terminal() do
    @show A[1]
    E = @view A[1:5,1:5]
    E[1] = 2.0
    @show A[1]
    
end</code></pre>
<pre id="plutouiterminal">
A[1] = 0.6952070004859242
A[1] = 2.0
</pre>



<div class="markdown"><p>However, this means that <code>@view A&#91;1:5,1:5&#93;</code> did not allocate an array &#40;it does allocate a pointer if the escape analysis is unable to prove that it can be elided. This means that in small loops there will be no allocation, while if the view is returned from a function for example it will allocate the pointer, ~80 bytes, but not the memory of the array. This means that it is O&#40;1&#41; in cost but with a relatively small constant&#41;.</p>
<h3>Asymptotic Cost of Heap Allocations</h3>
<p>Heap allocations have to locate and prepare a space in RAM that is proportional to the amount of memory that is calculated, which means that the cost of a heap allocation for an array is O&#40;n&#41;, with a large constant. As RAM begins to fill up, this cost dramatically increases. If you run out of RAM, your computer may begin to use <em>swap</em>, which is essentially RAM simulated on your hard drive. Generally when you hit swap your performance is so dead that you may think that your computation froze, but if you check your resource use you will notice that it&#39;s actually just filled the RAM and starting to use the swap.</p>
<p>But think of it as O&#40;n&#41; with a large constant factor. This means that for operations which only touch the data once, heap allocations can dominate the computational cost:</p>
</div>


<div class="markdown"><p>However, when the computation takes O&#40;n^3&#41;, like in matrix multiplications, the high constant factor only comes into play when the matrices are sufficiently small:</p>
</div>


<div class="markdown"><p>...</p>
</div>
<div class='manifest-versions'>
<p>Built with Julia 1.8.2 and</p>
BenchmarkTools 1.3.1<br>
PlutoUI 0.7.48<br>
StaticArrays 1.5.9
</div>

<!-- PlutoStaticHTML.End -->
~~~