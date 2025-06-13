module module_export_location

module BadStyle
    import Statistics

    include("SomeOtherSubmodule.jl")
    using .SomeOtherSubmodule

    include("SomeSubmodule.jl")
    using .SomeSubmodule

    foo()::Nothing = nothing
    bar()::String = "the bar is open"

    export bar # Bad: exports should be placed below the includes list
    export foo

end # module BadStyle

module GoodStyle
    import Statistics
    
    include("SomeOtherSubModule.jl")
    using .SomeOtherSubModule

    include("SomeSubmodule.jl")
    using .SomeSubmodule

    export foo
    export bar

    foo()::Nothing = nothing
    bar()::String = "the bar is open"

end # module GoodStyle

end # module module_export_location
