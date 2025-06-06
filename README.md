# JuliaCheck

Code checker for Julia language, based on [JuliaSyntax](https://github.com/JuliaLang/JuliaSyntax.jl).

This package is not listed in any registry yet, but it can be used, according to instructions from [this FAQ](https://github.com/JuliaRegistries/General#do-i-need-to-register-a-package-to-install-it), like this in the Julia REPL:
```
julia> ]

... pkg> add https://github.com/tiobe/JuliaCheck
```
or like this, both in the REPL or in a Julia script:
```
using Pkg; Pkg.add(url="https://github.com/tiobe/JuliaCheck")
```

Invocation of JuliaCheck:
```
usage: JuliaCheck.jl [--enable RULES [RULES...]] [-v] [--ast] [--llt]
                     [--version] [-h] infiles...

Code checker for Julia programming language.

positional arguments:
  infiles               One or more Julia files to check with
                        available rules.

optional arguments:
  --enable RULES [RULES...]
                        List of rules to check on the given files.
  -v, --verbose         Print debugging information.
  --ast                 Print syntax tree for the each input file.
  --llt                 Print lossless tree for the each input file.
  --version             show version information and exit
  -h, --help            show this help message and exit
```

When using the list of enabled rules, you must use `--` to separate that list from the list of files to be checked. E.g.:
```
julia src/JuliaCheck.jl --enable module-name-casing single-module-file -- file_to_check.jl
```

If no rules are specified in the command line, all rules are checked.
