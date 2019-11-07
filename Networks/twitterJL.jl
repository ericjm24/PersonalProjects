indexFile = "data/twitter_index"
friendsFile = "data/friends_small_indexed"
followersFile = "data/followers_small_indexed"
maxBuff = Int64(125000000)

struct twitterID
    id::UInt32
    followers::UInt32
    followersPosition::UInt64
    friends::UInt32
    friendsPosition::UInt64
end

function readIndexFile()
    file = open(indexFile, "r")
    numElements = Int64(read(file, UInt32))
    out = Vector{twitterID}(undef, numElements)
    temp = Vector{UInt32}(undef, 7)
    for k = 1:numElements
        read!(file, temp)
        out[k] = twitterID(temp[1], temp[2], reinterpret(UInt64, temp[3:4])[1], temp[5], reinterpret(UInt64, temp[6:7])[1])
    end
    return out
end

function printUser(user::twitterID)
    println("User ID: " * string(user.id, base=10))
    println("Followers: " * string(user.followers, base=10))
    println("Friends: " * string(user.friends, base=10))
end

function randUser(userArray::Vector{twitterID})
    numUsers = length(userArray)
    return userArray[Int64(ceil(rand()*numUsers))]
end

function readFollowers(user::twitterID)
    file = open(followersFile, "r")
    seek(file, user.followersPosition)
    output = Vector{UInt32}(undef, user.followers)
    read!(file, output)
    close(file)
    return output
end

function readFriends(user::twitterID)
    file = open(friendsFile, "r")
    seek(file, user.friendsPosition)
    output = Vector{UInt32}(undef, user.friends)
    read!(file, output)
    close(file)
    return output
end

function sparseAdjacencyMultiplyMV(M::Vector{UInt32}, V::Vector)
    out = Vector{typeof(V[1])}(undef, length(V))
    for t = 1:length(out)
        out[t]=0
    end
    ind = M[1]
    k = 2
    temp = Float64(0)
    L = length(M)
    while k <= L
        a = M[k]
        if a != 0
            temp += V[a]
            k += 1
        else
            out[ind] = temp
            k += 1
            if k > L
                break
            end
            temp = 0
            ind = M[k]
            k += 1
        end
    end
    return out
end

function sparseAdjacencyMultiplyMV(inFileName::String, V::Vector{Float64})
    file = open(inFileName, "r")
    seekend(file)
    totalUsers = Int64(position(file)/4)
    usersLeft = totalUsers
    println("Total length of file is " * string(Int64(position(file)/4), base=10))
    seekstart(file)
    out = Vector{typeof(V[1])}(undef, length(V))
    buffer = Vector{UInt32}(undef, maxBuff)
    for t = 1:length(V)
        out[t]=0
    end
    k = 1
    while true
        if usersLeft < maxBuff
            buffer = Vector{UInt32}(undef, usersLeft)
        end
        curPos = position(file)
        read!(file, buffer)
        usersLeft -= length(buffer)
        lastUser = length(buffer)
        while lastUser > 0
            if buffer[lastUser] == 0
                if usersLeft != 0
                    curPos += lastUser*4
                    seek(file, curPos)
                end
                break
            else
                lastUser -= 1
            end
        end
        numUsers = 0
        k = 2
        ind = buffer[1]
        temptot = 0.0
        while k <= lastUser
            if buffer[k] == 0
                out[ind] = temptot
                if k >= lastUser
                    break
                else
                    k += 1
                    ind = buffer[k]
                    k += 1
                    temptot = 0.0
                end
            else
                temptot += V[buffer[k]]
                k += 1
            end
        end
        if usersLeft <= 0
            break
        end
    end
    close(file)
    return out
end

function normalizeV(inVector::Vector{Float64})
    inVector = copy(inVector)
    mag = 0.0
    for k = 1:length(inVector)
        temp = inVector[k]
        mag += (temp*temp)
    end
    mag = sqrt(mag)
    for k = 1:length(inVector)
        inVector[k] /= mag
    end
    return inVector
end

function randV(vecLength::Int64)
    out = Vector{Float64}(undef, vecLength)
    for k = 1:vecLength
        out[k] = rand()
    end
    return normalizeV(out)
end

function dotVV(vec1::Vector{Float64}, vec2::Vector{Float64})
    len = length(vec1)
    if length(vec2) < len
        len = length(vec2)
    end
    out = 0.0
    for k = 1:len
        out += vec1[k]*vec2[k]
    end
    return out
end

function scalarMultSV(scalar, inVector::Vector{Float64})
    inVector = copy(inVector)
    for k = 1:length(inVector)
        inVector[k] *= scalar
    end
    return inVector
end

function addVV(alpha, VectorAlpha::Vector{Float64}, beta, VectorBeta::Vector{Float64})
    if length(VectorAlpha) == length(VectorBeta)
        VectorAlpha = copy(VectorAlpha)
        for k = 1:length(VectorAlpha)
            VectorAlpha[k] = alpha*VectorAlpha[k] + beta*VectorBeta[k]
        end
        return VectorAlpha
    elseif length(VectorAlpha) < length(VectorBeta)
        VectorBeta = copy(VectorBeta)
        shortLen = length(VectorAlpha)
        for k = 1:length(VectorBeta)
            if k <= shortLen
                VectorBeta[k] = alpha*VectorAlpha[k] + beta*VectorBeta[k]
            else
                VectorBeta[k]*=beta
            end
        end
        return VectorBeta
    else
        VectorAlpha=copy(VectorAlpha)
        shortLen = length(VectorBeta)
        for k = 1:length(VectorAlpha)
            if k <= shortLen
                VectorAlpha[k] = alpha*VectorAlpha[k] + beta*VectorBeta[k]
            else
                VectorAlpha[k] *= beta
            end
        end
        return VectorAlpha
    end
end

function distanceVV(vec1::Vector{Float64}, vec2::Vector{Float64}, align)
    dist = 0.0
    for k = 1:length(vec1)
        if align == true
            t = abs(vec1[k]) - abs(vec2[k])
        else
            t = vec1[k] - vec2[k]
        end
        dist += t*t
    end
    return sqrt(dist)
end

function sparsePowerIterate(adjacency::Vector{UInt32}, vecLength::Int64, epsilon)
    out = randV(vecLength)
    epsilon = abs(epsilon)
    e = 10.0*epsilon
    oldL = 10000.0
    lambda = 0.0
    while e > epsilon
        old = out
        out = sparseAdjacencyMultiplyMV(adjacency, old)
        lambda = dotVV(old, out)
        out = normalizeV(out)
        e = distanceVV(out, old, true)
        oldL = lambda
    end
    return out, lambda
end

function orthogonalizeV(inVec::Vector{Float64}, GSArray::Array{Float64,2})
    inVec = copy(inVec)
    vecLength, numVec = size(GSArray)
    for k = 1:numVec
        inVec = addVV(1.0, inVec, -dotVV(inVec, GSArray[:,k]), GSArray[:,k])
    end
    return inVec
end

function orthonomalizeV(inVec::Vector{Float64}, GSArray::Array{Float64,2})
    return normalizeV(orthogonalizeV(out, GSArray))
end

function sparsePowerIterate_wGS_step(adjacency::Vector{UInt32}, GSArray::Array{Float64, 2}, vecLength::Int64, epsilon)
    out = randV(vecLength)
    epsilon = abs(epsilon)
    e = 10.0*epsilon
    oldL = 10000.0
    lambda = 0.0
    while e > epsilon
        old = out
        out = sparseAdjacencyMultiplyMV(adjacency, old)
        out = orthogonalizeV(out, GSArray)
        lambda = dotVV(old, out)
        out = normalizeV(out)
        e = distanceVV(out, old, true)
        oldL = lambda
    end
    return out, lambda
end

function sparsePowerIterate_wGS(adjacency::Vector{UInt32}, vecLength::Int64, numVecs::Int64, epsilon)
    if numVecs<=1
        return sparsePowerIterate(adjacency, vecLength, epsilon)
    end
    out = Array{Float64,2}(undef, vecLength, numVecs)
    lambda = Vector{Float64}(undef, numVecs)
    out[:,1], lambda[1] = sparsePowerIterate(adjacency, vecLength, epsilon)
    println("1:")
    println(lambda[1])
    for k = 2:numVecs
        out[:,k], lambda[k] = sparsePowerIterate_wGS_step(adjacency, out[:,1:k-1], vecLength, epsilon)
        println(string(k, base=10)*": ")
        println(lambda[k])
    end
    return out, lambda
end

function sparseArnoldiIterate(adjacency::Vector{UInt32}, vecLength::Int64, numVecs::Int64)
    out = Array{Float64, 2}(undef, vecLength, numVecs)
    out[:,numVecs] = randV(vecLength)
    for i = 1:numVecs-1
        out[:,numVecs-i] = normalizeV(sparseAdjacencyMultiplyMV(adjacency, out[:, numVecs-i+1]))
    end
    for m = 2:numVecs
        for n = 1:m-1
            out[:,m] = addVV(1, out[:,m], -dotVV(out[:,m], out[:,n]), out[:,n])
        end
        out[:,m] = normalizeV(out[:,m])
    end
    eigs = Vector{Float64}(undef, numVecs)
    for t = 1:numVecs
        eigs[t] = dotVV(out[:,t], sparseAdjacencyMultiplyMV(adjacency, out[:,t]))
    end
    return out, eigs
end

function calculateInfluenceVector(inVector::Vector{Float64}, adjacency::Vector{UInt32}, c::Float64, eigV::Array{Float64,2}, eigs::Vector{Float64}, tol::Float64)
    inVector = copy(inVector)
    tol = abs(tol)
    rat = abs(maximum(eigs)/minimum(eigs))
    n = 1
    temp = rat
    while temp > tol
        n += 1
        temp *= abs(eigs[length(eigs)])*abs(c)
    end
    numVecs = length(eigs)
    out = Vector{Float64}(undef, length(inVector))
    for t = 1:length(out)
        out[t]=0.0
    end
    for k = 1:numVecs
        dot = dotVV(inVector, eigV[:,k])
        out = addVV(1.0, out, eigs[k]*dot/(1.0 - c*eigs[k]), eigV[:,k])
        inVector = addVV(1.0, inVector, -dot, eigV[:,k])
    end
    for m = 1:n
        inVector = sparseAdjacencyMultiplyMV(adjacency, inVector)
        out = addVV(1.0, out, 1.0, inVector)
        if m < n
            inVector = scalarMultSV(c,inVector)
        end
    end
    return out
end

function findUser(id::UInt32, userArray::Vector{twitterID})
    kStart = 1
    kEnd = length(userArray)
    if userArray[kStart].id == id
        return userArray[kStart]
    end
    if userArray[kEnd].id == id
        return userArray[kEnd]
    end
    n = 1
    while n < 10000
        kTemp = Int64(floor((kStart + kEnd)/2))
        if userArray[kTemp].id == id
            return userArray[kTemp]
        elseif kTemp==kStart
            return nothing
        elseif userArray[kTemp].id < id
            kStart = kTemp
        else
            kEnd = kTemp
        end
        n += 1
    end
    return nothing
end

function findUserIndex(id::UInt32, userArray::Vector{twitterID})
    kStart = 1
    kEnd = length(userArray)
    if userArray[kStart].id == id
        return kStart
    end
    if userArray[kEnd].id == id
        return kEnd
    end
    n = 1
    while n < 10000
        kTemp = Int64(floor((kStart + kEnd)/2))
        if userArray[kTemp].id == id
            return kTemp
        elseif kTemp==kStart
            return 0
        elseif userArray[kTemp].id < id
            kStart = kTemp
        else
            kEnd = kTemp
        end
        n += 1
    end
    return 0
end

function randomStep(user::twitterID, userArray::Vector{twitterID})
    x = rand(1:3)
    if x == 1
        return user
    elseif x == 2
        return findUser(rand(readFriends(user)), userArray)
    else
        return findUser(rand(readFollowers(user)), userArray)
    end
end

function randomWalk(startUser::twitterID, numSteps::Int64,userArray::Vector{twitterID})
    out =  Vector{twitterID}(undef, numSteps+1)
    out[1] = startUser
    for k = 1:numSteps
        out[k+1] = randomStep(out[k], userArray)
    end
    return out
end

function writeIndexFile(filename, out::Vector{twitterID})
    out32 = Vector{UInt32}(undef, Int64(7*length(out)))
    for k = 1:length(out)
        out32[7*k-6] = out[k].id
        out32[7*k-5] = out[k].followers
        out32[7*k-4:7*k-3] = reinterpret(UInt32, [out[k].followersPosition])
        out32[7*k-2] = out[k].friends
        out32[7*k-1:7*k] = reinterpret(UInt32, [out[k].friendsPosition])
    end
    file = open(filename, "w")
    write(file, UInt32(length(out)))
    write(file, out32)
    close(file)
end

function mergeIndexFiles(friendsIndexFile, followersIndexFile)
    #TO DO: Clean up this function, remove the hardcoded number of users before the while loop
    file1 = open(friendsIndexFile, "r")
    seekend(file1)
    file1Length = Int64(position(file1)/4)
    seekstart(file1)
    friends = Vector{UInt32}(undef, file1Length)
    read!(file1, friends)
    close(file1)

    file2 = open(followersIndexFile, "r")
    seekend(file2)
    file2Length = Int64(position(file2)/4)
    followers = Vector{UInt32}(undef, file2Length)
    seekstart(file2)
    read!(file2, followers)
    close(file2)

    k1 = 1
    k2 = 1
    k = 1
    out = Vector{twitterID}(undef, 41652229) #TO DO: Remove this hardcoded number
    while true
        if k1 > file1Length && k2>file2Length
            break
        end
        if k1 > file1Length || friends[k1] > followers[k2]
            temp = twitterID(followers[k2], followers[k2+1], reinterpret(UInt64, followers[k2+2:k2+3])[1], 0, 0)
            out[k] = temp
            k += 1
            k2 += 4
            continue
        end
        if k2 > file2Length || followers[k2] > friends[k1]
            temp = twitterID(friends[k1], 0, 0, friends[k1+1], reinterpret(UInt64, friends[k1+2:k1+3])[1])
            out[k] = temp
            k += 1
            k1+= 4
            continue
        end
        temp = twitterID(friends[k1], followers[k2+1], reinterpret(UInt64, followers[k2+2:k2+3])[1], friends[k1+1], reinterpret(UInt64, friends[k1+2:k1+3])[1])
        out[k] = temp
        k += 1
        k1+=4
        k2 += 4
    end
    followers = nothing
    friends = nothing
    k -= 1
    println(k)
end

function makeSmallFile(filename, bReverse::Bool)
    temp = Array{UInt64,1}(undef,1)
    file = open(filename, "r")
    temp[1] = read(file, UInt64)
    if bReverse
        yStart,xStart = reinterpret(UInt32, temp)
    else
        xStart,yStart = reinterpret(UInt32, temp)
    end
    seekstart(file)
    outFileName = filename*"_small"
    outFile = open(outFileName, "w")
    write(outFile, xStart)
    write(outFile, yStart)
    while !eof(file)
        temp[1] = read(file, UInt64)
        if bReverse
            y,x = reinterpret(UInt32, temp)
            if x == xStart
                if y != yStart
                    write(outFile, y)
                    yStart = y
                end
            else
                write(outFile, UInt32(0))
                write(outFile, x)
                write(outFile, y)
                xStart = x
                yStart = y
            end
        else
            x,y = reinterpret(UInt32, temp)
            if y == xStart
                if x != yStart
                    write(outFile, x)
                    xStart = x
                end
            else
                write(outFile, UInt32(0))
                write(outFile, x)
                write(outFile, y)
                xStart = x
                yStart = y
            end
        end

    end
    write(outFile, UInt32(0))
    close(file)
    close(outFile)
end

function makeIndexFile(filename)
    #Input should be the name of the LARGE file, not the _small file
    temp64 = Array{UInt64, 1}(undef, 1)
    temp128 = Array{UInt128, 1}(undef, 1)
    inFileName = filename * "_small"
    file = open(filename, "r")
    outFileName = filename * "_index"
    outFile = open(outFileName, "w")
    posStart = UInt64(position(file))
    idStart = read(file, UInt32)
    friends = UInt32(0)
    while !eof(file)
        id = read(file, UInt32)
        if id == UInt32(0)
            temp64 = reinterpret(UInt64, [idStart, friends])
            temp128 = reinterpret(UInt128, [temp64[1], posStart])
            write(outFile, temp128[1])
            if eof(file)
                break
            else
                posStart = UInt64(position(file))
                idStart = read(file, UInt32)
                friends = UInt32(0)
            end
        else
            friends += UInt32(1)
        end
    end
    close(file)
    close(outFile)
end

function bIncludeUserInSubnetwork(user::UInt32, startUser, endUser)
    bOut = false
    if user == 0
        bOut = true
    elseif (user >= startUser) && (user <= endUser)
        bOut = true
    end
    return bOut
end

function stripZeroes(inVector::Vector{UInt32})
    numUsers = 0
    bZeroes = false
    for k = 1:length(inVector)
        if inVector[k] > 0
            bZeroes = false
            numUsers += 1
        elseif bZeroes == false && inVector[k] == 0
            bZeroes = true
            numUsers += 1
        end
    end
    out = Vector{UInt32}(undef, numUsers)
    numUsers = 0
    bZeroes = false
    for k = 1:length(inVector)
        if inVector[k] > 0
            bZeroes = false
            numUsers += 1
            out[numUsers] = inVector[k]
        elseif bZeroes == false && inVector[k] == 0
            bZeroes = true
            numUsers += 1
            out[numUsers] = 0
        end
    end
    return out
end

function buildSubNetwork(inFileName, outFileName, startUser, endUser)
    inFile = open(inFileName, "r")
    outFile = open(outFileName, "w")
    x = read(inFile, UInt32)
    if x >= startUser && x <= endUser
        bInclude = true
    else
        bInclude = false
    end
    seekstart(inFile)
    while !eof(inFile)
        x = read(inFile, UInt32)
        if bInclude == true && (x >= startUser && x <= endUser)
            write(outFile, x)
        elseif x == 0
            if bInclude == true
                write(outFile, x)
            end
            if eof(inFile)
                break
            end
            x = read(inFile, UInt32)
            if (x >= startUser) && (x <= endUser)
                write(outFile, x)
                bInclude = true
            else
                bInclude = false
            end
        end
    end
    close(inFile)
    close(outFile)
end
