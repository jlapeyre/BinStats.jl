module BinStats
import JLD2
import Random

export readhex, writehex
export Bin64
export revbits

struct Bin64
    x::UInt64
end

function Base.show(io::IO, b::Bin64)
    print(io, string(b.x, base=2, pad=64))
#    print(io, reverse(string(b.x, base=2, pad=64)))
end

function Base.show(io::IO, v::Vector{<:Bin64})
    for x in v
        show(io, x)
        println(io)
    end
end

Random.rand(rng::Random.AbstractRNG, ::Random.SamplerType{Bin64}) = Bin64(rand(rng, UInt64))

# First bit is leftmost, that is MSB
function Base.getindex(b::Bin64, i::Integer)
    return Bool((b.x >> (64 - i)) & 1)
end

function Base.getindex(b::Bin64, inds::AbstractVector{<:Integer})
    return BitArray(b[i] for i in inds)
end

function readhex(fname, ::Type{T}=Bin64) where T
    a = Vector{T}()
    open(fname) do f
        foreach(line -> append!(a, parsehexline(line, T)), readlines(f))
    end
    return a
end


# These explict reinterpretations are slightly faster than using the generic builtin reinterpret

@inline shft(x, n) = x << (8 * n)
@inline touint(::Type{T}, v::UInt8...) where T = touint(T, v)
@inline touint(::Type{UInt16}, v) = toUInt16(v)
@inline touint(::Type{UInt32}, v) = toUInt32(v)
@inline touint(::Type{UInt64}, v) = toUInt64(v)
@inline touint(::Type{Bin64}, v) = Bin64(touint(UInt64, v))

@inline toUInt16(v::Union{AbstractVector{UInt8}, NTuple{2, UInt8}}) = shft(UInt16(v[1]), 1) | UInt16(v[2])

@inline function toUInt32(v::Union{AbstractVector{UInt8}, NTuple{4, UInt8}})
    return shft(UInt32(v[1]), 3) | shft(UInt32(v[2]), 2) |
        shft(UInt32(v[3]), 1) | UInt32(v[4])
end

@inline function toUInt64(v::Union{AbstractVector{UInt8}, NTuple{8, UInt8}})
    shft(UInt64(v[1]), 7) | shft(UInt64(v[2]), 6) |
        shft(UInt64(v[3]), 5) | shft(UInt64(v[4]), 4) |
        shft(UInt64(v[5]), 3) | shft(UInt64(v[6]), 2) |
        shft(UInt64(v[7]), 1) | UInt64(v[8])
end

function _reinterp(::Type{T}, bytes, start, stop) where {T <: Union{UInt16, UInt32, UInt64}}
    return touint(T, @view(bytes[start:stop]))
end

function _reinterp(::Type{T}, bytes, start, stop) where {T}
    return only(reinterpret(T, @view(bytes[stop:-1:start])))
end

function parsehexline(s::AbstractString, ::Type{T}=Bin64) where T
    bytes = hex2bytes(s)
    T <: UInt8 && return bytes
    sizeT = sizeof(T)
    v = Vector{T}(undef, div(length(bytes), sizeT))
    for i in 1:length(v)
        stop = sizeT * i
        start = stop - sizeT + 1
        v[i] = _reinterp(T, bytes, start, stop)
    end
    return v
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
    v = reverse!(reinterpret(UInt8, [n]))
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

end # module BinStats
