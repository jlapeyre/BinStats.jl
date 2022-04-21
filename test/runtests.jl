using Test
using BinStats
import FileCmp

const hexfile = "test_dump5.hex"

@testset "BinStats" begin
    for T in (UInt64, Bin64)
        v = readhex(hexfile, T)
        @test length(v) == 26
        let tfile = "test_write.hex"
            try
                writehex(tfile, v)
                v1 = readhex(tfile, T)
                @test v == v1
                @test FileCmp.filecmp(hexfile, tfile)
            finally
                rm(tfile)
            end
        end
    end
    @test rand(Bin64) isa Bin64
    @test eltype(rand(Bin64, 3)) <: Bin64
end

