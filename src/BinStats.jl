module BinStats
import JLD2
import Random

export readhex, writehex
export Bin64

struct Bin64
    x::UInt64
end

function Base.show(io::IO, b::Bin64)
    print(io, reverse(string(b.x, base=2, pad=64)))
end

function Base.show(io::IO, v::Vector{<:Bin64})
    for x in v
        show(io, x)
        println(io)
    end
end

Random.rand(rng::Random.AbstractRNG, ::Random.SamplerType{Bin64}) = Bin64(rand(rng, UInt64))

function Base.getindex(b::Bin64, i::Integer)
    return Bool((b.x >> (i - 1)) & 1)
end

function Base.getindex(b::Bin64, inds::AbstractVector{<:Integer})
    return BitArray(b[i] for i in inds)
end

function readhex(fname, ::Type{T}=Bin64) where T
    a = Vector{T}()
    open(fname) do f
        foreach(line -> append!(a, reinterpret(T, hex2bytes(line))), readlines(f))
    end
    return a
end

"""
    writehex(v::AbstractVector{UInt64}, fname)

# Example
julia> writehex(rand(UInt64, 10^8))
"""
function writehex(fname::AbstractString, v::AbstractVector; rep=2)
    open(fname, "w") do io
        writehex(io, v; rep=rep)
    end
end

function writehex(io::IO, v::Vector; rep=2)
    for (i, x) in enumerate(v)
        writehex(io, x)
        if iszero(i % rep)
            println(io)
        end
    end
    if ! iszero(length(v) % rep)
        println(io)
    end
end

writehex(io::IO, b::Bin64) = writehex(io, b.x)
function writehex(io::IO, n::UInt64)
    v = reinterpret(UInt8, [n])
    for x in v
        print(io, uppercase(string(x, base=16, pad=2)))
    end
end

"""
    eachrow(v, col_num)

Return an iterator over the `col_num`th column of the vector `v`.

# Examples
To return a Vector, use `collect`.
```juliarepl
julia> v = rand(Bin64, 10)
julia> collect(eachrow(v, 2))
```

Compute run-length encoding of values
in column 2.
```juliarepl
julia> using StatsBase
julia> rle(collect(eachrow(v, 2)))
```

Count the number of ones in column 2
```juliarepl
julia> count(isone, eachrow(v, 2))
```
"""
Base.eachrow(v::AbstractVector{<:Bin64}, col_num) = (x[col_num] for x in v)

# Following it perhaps not useful
# """
#     oncol(f, i)

# Return a function that calls `f` on the `i` element of
# its input

# # Example
# Count the number of ones in column 2
# ```juliarepl
# julia> count(oncol(isone, 2), v)
# ```
# """
# oncol(f, i) = b -> f(b[i])

end # module BinStats
