include("twitterJL.jl")

userArray = readIndexFile()

function twitterConvert(inFileName::String, outFileName::String)
    inFile = open(inFileName, "r")
    outFile = open(outFileName, "w")
    y = UInt32(0)
    x = UInt32(0)
    while !eof(inFile)
        x = read(inFile, UInt32)
        if x != 0
            y = UInt32(findUserIndex(x, userArray))
        else
            y = UInt32(0)
        end
        write(outFile, y)
    end
    close(inFile)
    close(outFile)
end
