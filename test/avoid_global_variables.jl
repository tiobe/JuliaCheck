some_number::Float64 = 1
const global some_other_number = 42

function foo()
    global yet_another_number = 7.0
    return nothing
end

SOME_NUMBER::Float64
global const SOME_OTHER_NUMBER::Int = 42
const N1 = const N2 = 3.14159

function bar()
    global YET_ANOTHER_NUMBER = 7.0
    return nothing
end
