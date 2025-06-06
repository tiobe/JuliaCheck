
# Bad
const MAGTHRESHOLD::Float64 = 3.00 # In ppm
const THEANSWER = 42

struct MyType
    x::Int
end
const UNDOCUMENTED_GLOBAL_ITEM = MyType(3)

# Good
"MAG_THRESHOLD is dimensionless. A value of 0 means no expansion."
const MAG_THRESHOLD::Float64 = 3e-6

"The Answer to the Ultimate Question of Life, the Universe, and Everything"
const THE_ANSWER = 42

"Cierto!"
const E_VERO = true





