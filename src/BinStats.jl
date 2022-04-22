module BinStats
import JLD2
import Random

export readhex, writehex, bitmatrix, parsehexline, bitprint
export Bin64

struct Bin64 <: Unsigned
    x::UInt64
end

@inline Base.UInt64(b::Bin64) = b.x

function Base.show(io::IO, b::Bin64)
    print(io, string(b.x, base=2, pad=64))
end

function Base.show(io::IO, v::Vector{<:Bin64})
    n = length(v)
    for (i, x) in enumerate(v)
        show(io, x)
        print(io)
        if i != n
            println(io)
        end
    end
end

Random.rand(rng::Random.AbstractRNG, ::Random.SamplerType{Bin64}) = Bin64(rand(rng, UInt64))

# First bit is leftmost, that is MSB
@inline function Base.getindex(b::Bin64, i::Integer)
    return Bool((b.x >> (64 - i)) & 1)
end

@inline function Base.getindex(b::Bin64, inds::AbstractVector{<:Integer})
    return BitArray(b[i] for i in inds)
end

"""
    bitmatrix(m::AbstractVector{<:Union{UInt64,Bin64}})

Convert `m` to a `64 x n` `BitMatrix`, where `n == length(m)`.

In contrast to the builtin construction, the semantic order of the bits in the original array are
preserved. In otherwords each `UInt64` is bit-reversed befor copying into the constructed
`BitMatrix`.

Furthermore, the output is wrapped in a `Transpose` before returning. Thus, the output has the same
semantics of `Vector{Bin64}` when treated as a matrix. If the input vector `m` was read with
`readhex`, then indexing into the output `BitMatrix` will access the bits in the order they
appear in the input file.

You may get better performance or flexibility by converting the `Transpose` object to a concrete
`BitMatrix` like this: `collect(bitmatrix(v))`.
"""
bitmatrix(m::AbstractVector{UInt64}) = _bitmatrix(m, bitreverse)
bitmatrix(m::AbstractVector{Bin64}) = _bitmatrix(m, x -> bitreverse(x.x))
@inline function _bitmatrix(m, revfunc)  # @inline really necessary here
    ba = BitArray(undef, (64, length(m)))
    copy!(ba.chunks, revfunc.(m))
    return transpose(ba)
end

"""
    bitprint([io::IO], v::AbstractVector{Bool})
    bitprint([io::IO], m::AbstractMatrix{Bool})

Print `v` or `m` in a compact form, with adjacet zeros and ones.
"""
bitprint(x::AbstractArray{Bool}) = bitprint(Base.stdout, x)
bitprint(io::IO, v::AbstractVector{Bool}) = print(io, join(Int8.(v), ""))
function bitprint(io::IO, m::AbstractMatrix{Bool})
    rows = eachrow(m)
    n = length(rows)
    for (i, r) in enumerate(rows)
        bitprint(io, r)
        if i != n
            println(io)
        end
    end
end


"""
    readhex(fname, ::Type{T}=Bin64) where T

Read ascii hex-coded numbers into, and return, an array of eltype `T`.

`T` can be, for example, `Bin64`, `UInt8` through `UInt128`, and `BitMatrix`.
Each line of the file will be converted and appended to the output array.
So, codes for a single output number may not be split across input lines.

If `T` is `BitMatrix`, then the returned object is a `BitMatrix` with `64`
columns.
"""
function readhex(fname, ::Type{T}=Bin64) where T
    T <: BitMatrix && return bitmatrix(readhex(fname, UInt64))
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

# When Julia reinterprets, the first input byte is the least significant
# In contrast, in our functions below, the first byte is the most significant.
# These are often faster as well, because they return a single integer rather than an array.

@inline function toUInt16(v::Union{AbstractVector{UInt8}, NTuple{2, UInt8}})
    return shft(UInt16(v[1]), 1) | UInt16(v[2])
end

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

@inline function _reinterp(::Type{T}, bytes, start, stop) where {T <: Union{UInt16, UInt32, UInt64}}
    return touint(T, @view(bytes[start:stop]))
end

# For UInt128, etc. we have not written a special purpose routine. So call Julia routines.
@inline function _reinterp(::Type{T}, bytes, start, stop) where {T}
    return only(reinterpret(T, @view(bytes[stop:-1:start])))
end

"""
    parsehexline(s::AbstractString, ::Type{T}=Bin64) where T

Convert the hex-coded numbers in `s` to an array of numbers. In contrast
to `reinterpret` in Julia, the order of the bits in the line is preserved
in the output array.
"""
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
    eachrow(v::AbstractVector{<:Bin64}, col_num)

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
