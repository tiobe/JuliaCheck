module JuliaCheck

import JuliaSyntax as JS
using ArgParse: ArgParseSettings, @project_version, @add_arg_table!, parse_args

include("Properties.jl")
import .Properties

include("Checks.jl")
import .Checks: setup_filter

include("Process.jl")
import .Process

function parse_commandline()
    s = ArgParseSettings(
        description = "Code checker for Julia programming language.",
        add_version = true, version = @project_version,
    )

    @add_arg_table! s begin
        "--enable"
            help = "List of rules to check on the given files."
            arg_type = String
            nargs = '+'
            dest_name = "rules"
        "--verbose", "-v"
            help = "Print debugging information."
            action = :store_true
        "--ast"
            help = "Print syntax tree for the each input file."
            action = :store_true
        "--llt"
            help = "Print lossless tree for the each input file."
            action = :store_true
        "infiles"
            help = "One or more Julia files to check with available rules."
            nargs = '+'
            arg_type = String
            required = true
    end

    return parse_args(s)
end

function main()
    arguments = parse_commandline()
    if arguments["verbose"]
        ENV["JULIA_DEBUG"] = "Main,JuliaCheck"
    end
    setup_filter(arguments["rules"])
    for in_file in arguments["infiles"]
        if !(Base.Filesystem.isfile(in_file))
            @error ">> Error: cannot read '$in_file' as a file."
        else
            print("\n>> Processing file '")
            printstyled(in_file; color=:green)
            print("'...\n")
            Process.check(in_file;
                          print_ast = arguments["ast"], print_llt = arguments["llt"])
        end
    end
    println()
end

main()

end
