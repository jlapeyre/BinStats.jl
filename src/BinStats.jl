module BinStats
import JLD2

export readhex, writehex

function readhex(fname)
    a = Vector{UInt64}()
    open(fname) do f
        foreach(line -> append!(a, reinterpret(UInt64, hex2bytes(line))), readlines(f))
    end
    return a
end

"""
    writehex(v::AbstractVector{UInt64}, fname)

# Example
julia> writehex(rand(UInt64, 10^8))
"""
function writehex(v::AbstractVector{UInt64}, fname)
    open(fname, "w") do io
        writedata(io, v)
    end
end

function writehex(io::IO, v::AbstractVector{UInt64})
    foreach(x -> println(io, string(x, base=16, pad=16)), v)
end

end # module BinStats
