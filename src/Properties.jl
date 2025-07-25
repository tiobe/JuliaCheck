module Properties

import JuliaSyntax: Kind, GreenNode, SyntaxNode, SourceFile, @K_str, @KSet_str,
    head, kind, numchildren, sourcetext, span, untokenize, JuliaSyntax as JS

import ..LosslessTrees: LosslessNode, get_start_coordinates, start_index

export AnyTree, NullableNode, EOL, MAX_LINE_LENGTH, SF,

    children, closes_module, closes_scope, expr_depth, expr_size,

    fake_green_node, find_lhs_of_kind, first_child,

    get_assignee, get_func_arguments, get_func_body, get_func_name,
    get_imported_pkg, get_iteration_parts, get_module_name, get_number,
    get_struct_members, get_struct_name,

    haschildren, increase_counters, is_abstract, is_array_indx, is_assignment,
    is_constant, is_eq_neq_comparison, is_eval_call, is_export,
    is_fat_snake_case, is_flow_cntrl,is_function, is_global_decl, is_import,
    is_include, is_infix_operator, is_literal_number, is_loop, is_lower_snake,
    is_module, is_operator, is_range, is_separator, is_stop_point, is_struct,
    is_toplevel, is_type_op, is_union_decl, is_upper_camel_case,

    lines_count, opens_scope, report_violation, reset_counters,
    source_column, source_index, source_text, to_pascal_case


## Types
const AnyTree = Union{SyntaxNode, GreenNode, LosslessNode}
const NullableString = Union{String, Nothing}
const NullableNode = Union{AnyTree, Nothing}
const NodeAndString = Tuple{AnyTree, NullableString}


## Global definitions
global SF::SourceFile
SOURCE_INDEX = 0
SOURCE_LINE = 0
SOURCE_COL = 0
const MAX_LINE_LENGTH = 92
const EOL = (Sys.iswindows() ? "\n\r" : "\n")


## Functions

function report_violation(node::SyntaxNode;
                          severity::Int, user_msg::String,
                          summary::String, rule_id::String)::Nothing
    line, column = JS.source_location(node)
    printstyled("\n$(JS.filename(node))($line, $(column)):\n";
                underline=true)
    JS.highlight(stdout, node; note=user_msg, notecolor=:yellow,
                               context_lines_after=0, context_lines_before=0)
    _report_common(severity, rule_id, summary)
end
function report_violation(node::LosslessNode; delta::Int=0,
                          severity::Int, user_msg::String,
                          summary::String, rule_id::String)::Nothing
    line, column = get_start_coordinates(node)
    if startswith(node.text, '\n')
        leol = length(EOL)
        line += leol
        delta += leol
        column = 0  # invalid index, but will be compensated by `delta`
    end
    report_violation(index = start_index(node) + delta,
                     len = length(node) - delta,
                     line = line, col = column + delta,
                     severity = severity, rule_id = rule_id,
                     user_msg = user_msg, summary = summary)
end
function report_violation(; index::Int, len::Int, line::Int, col::Int,
                            severity::Int, user_msg::String,
                            summary::String, rule_id::String)::Nothing
    printstyled("\n$(JS.filename(SF))($line, $col):\n";
                underline=true)
    JS.highlight(stdout, SF, index:index+len-1;
                 note=user_msg, notecolor=:yellow,
                 context_lines_after=0, context_lines_before=0)
    _report_common(severity, rule_id, summary)
end
function _report_common(severity::Int, rule_id::String, summary::String)::Nothing
    printstyled("\n$summary"; color=:cyan)
    printstyled("\nRule:"; underline=true)
    printstyled(" $rule_id. ")
    printstyled("Severity:"; underline=true)
    printstyled(" $severity\n")
end


function fake_green_node(kind::Kind; length::Int=0)
    return GreenNode{Kind}(kind, length, nothing)
end


function is_lower_snake(s::AbstractString)::Bool
    return isnothing(match(r"[[:upper:]]", s))
end
function is_upper_camel_case(s::AbstractString)::Bool
    m = match(r"([[:upper:]][[:lower:][:digit:]]+)+", s)
    return !isnothing(m) && length(m.match) == length(s)
end
function is_fat_snake_case(s::AbstractString)::Bool
    m = match(r"[[:upper:]_[:digit:]]+", s)
    return !isnothing(m) && length(m.match) == length(s)
end


is_toplevel(  node::AnyTree)::Bool = kind(node) == K"toplevel"
is_module(    node::AnyTree)::Bool = kind(node) == K"module"
is_assignment(node::AnyTree)::Bool = kind(node) == K"="
is_function(  node::AnyTree)::Bool = kind(node) == K"function"
is_struct(    node::AnyTree)::Bool = kind(node) == K"struct"
is_abstract(  node::AnyTree)::Bool = kind(node) == K"abstract"
is_array_indx(node::AnyTree)::Bool = kind(node) == K"ref"
is_loop(          node::AnyTree)::Bool = kind(node) in KSet"while for"
is_separator(     node::AnyTree)::Bool = kind(node) in KSet", ;"
is_flow_cntrl(    node::AnyTree)::Bool = kind(node) in KSet"if for while try"
is_literal_number(node::AnyTree)::Bool = kind(node) in KSet"Float Integer"

# When searching for a parent node of a certain kind, we stop at these nodes:
is_stop_point(node::AnyTree)::Bool =
    kind(node) ∈ KSet"function module do let toplevel macro"

function is_eval_call(node::AnyTree)::Bool
    if kind(node) ∈ KSet"call macrocall" && haschildren(node)
        txt = string(children(node)[1])
        if txt == "@eval" || txt == "eval"
            return true
        else
            x = children(node)[1]
            if kind(x) == K"." && haschildren(x)
                a = children(x)[1]
                b = children(x)[2]
                if kind(a) == kind(b) == K"Identifier"
                    return string(a) == "Core" && string(b) == "eval"
                end
            end
        end
    end
    return false
end

function is_mod_toplevel(node::AnyTree)::Bool
    return is_toplevel(node) ||
            (kind(node) == K"block" && is_module(node.parent))
end
function is_global_decl(node::AnyTree)::Bool
    return kind(node) ∈ KSet"global const" ||
            # An assignment or base declaration at the (module's) top-level
            # declares a global variable
            (kind(node) ∈ KSet"= ::" && is_mod_toplevel(node.parent))
end
function is_constant(node::AnyTree)::Bool
    return kind(node) == K"const" ||
           (kind(node) == K"global" && haschildren(node) &&
            kind(children(node)[1]) == K"const")
end

function is_union_decl(node::SyntaxNode)::Bool
    if kind(node) == K"curly" && haschildren(node)
        first_child = children(node)[1]
        return kind(first_child) == K"Identifier" && string(first_child) == "Union"
    end
    return false
end

function is_operator(node::AnyTree)::Bool
    return  JS.is_prefix_op_call(node) ||
            is_infix_operator(node)  ||
            JS.is_postfix_op_call(node)
end
function is_infix_operator(node::AnyTree)::Bool
    return JS.is_infix_op_call(node) || JS.is_operator(node)
end

is_type_op(node::AnyTree)::Bool = kind(node) in KSet":: <: >:"

function is_eq_neq_comparison(node::AnyTree)::Bool
    if kind(node) == K"call" && numchildren(node) == 3
        infix_op = children(node)[2]
        return string(infix_op) ∈ ["==", "===", "≡", "!=", "≠", "!==", "≢"]
    end
    return false
end

function is_range(node::SyntaxNode)::Bool
    if kind(node) == K"call" && numchildren(node) >= 2
        kids = children(node)
        return (
            (kind(kids[1]) == K"Identifier" && string(kids[1]) == "range")
            ||
            (kind(kids[2]) == K"Identifier" && string(kids[2]) == ":")
           )
    end
    return false
end

function is_include(node::AnyTree)::Bool
    if kind(node) == K"call" && haschildren(node)
        id = children(node)[1]
        return kind(id) == K"Identifier" && string(id) == "include"
    end
    return false
end
is_import(node::AnyTree)::Bool = kind(node) in KSet"import using" || is_include(node)
is_export(node::AnyTree)::Bool = kind(node) == K"export"


function inside(node::SyntaxNode, predicate::Function)::Bool
    return !isnothing(node.parent) && (     # if we reach the top, return false
        predicate(node.parent) ||           # test the node's parent
        inside(node.parent, predicate)      # if false, keep going up
    )
end

function opens_scope(node::SyntaxNode)
    return is_function(node) ||
           kind(node) ∈ [KSet"for while try do let macro generator"]
                                # comprehensions contain a generator
end
function closes_scope(node::SyntaxNode)
    return kind(node) == K"end" && opens_scope(node.parent)
end
function closes_module(node::SyntaxNode)
    return kind(node) == K"end" && is_module(node.parent)
end

"""
Return the node carrying the function's name.
"""
function get_func_name(node::SyntaxNode)::NullableNode
    @assert is_function(node) "Expected a [function] node, got [$(kind(node))]."
    fname = find_lhs_of_kind(K"Identifier", node)
    if isnothing(fname)
        # We give it one more chance to find the function's name: it will return
        # the name of the operator being redefined, or `nothing`.
        return _is_exception_op_redef(children(node)[1])
    end
    if kind(fname.parent) == K"."  # In this case, the 1st child is a module name
        fname = children(fname.parent)[2]
    end
    if kind(fname) == K"quote"  # Overloading an operator, which comes next
        fname = children(fname)[1]
    end
    return fname
end

function _is_exception_op_redef(node::SyntaxNode)::NullableNode
    if kind(node) == K"call"
        fname = children(node)[1]
        if kind(fname) ∈ KSet"$ & :"
            return fname

        elseif kind(fname) == K"quote"
            fname = children(fname)[1]
            if kind(fname) == K"::" return fname end
        end
    end
    return nothing
end

"""
Return a list of nodes representing the arguments of a function.
"""
function get_func_arguments(node::SyntaxNode)::Vector{SyntaxNode}
    @assert is_function(node) "Expected a [function] node, got [$(kind(node))]."
    call = find_lhs_of_kind(K"call", children(node)[1])
    if isnothing(call)
        # Probably a function "stub", which declares a function name but no methods.
        return []
    end
    return children(call)[2:end]    # discard the function's name (1st identifier in this list)
end

function get_func_body(node::SyntaxNode)::NullableNode
    @assert is_function(node) "Expected a [function] node, got [$(kind(node))]."
    if ! haschildren(node) || length(children(node)) < 2
        # Probably a function "stub", which declares a function name but no methods.
        return nothing
    end
    return children(node)[2]
end


function get_assignee(node::SyntaxNode)::NodeAndString
    @assert kind(node) == K"=" "Expected a [=] node, got [$(kind(node))]."
    assignee = find_lhs_of_kind(K"Identifier", node)
    # FIXME In case of field access (`my_struct.some_field = value`), this may
    # not be what we want. Perhaps other cases as well?
    # Yes, also in redefinition of operators like `&`, `$` or `:`
    if isnothing(assignee)
        @debug "No identifier found in assignment $(JS.source_location(node))" node
        throw("No identifier found in assignment!")
    end
    return (assignee, string(assignee))
end


function get_struct_name(node::SyntaxNode)::NullableNode
    @assert kind(node) == K"struct" "Expected a [struct] node, got [$(kind(node))]."
    return find_lhs_of_kind(K"Identifier", node)
end

function get_struct_members(node::SyntaxNode)::Vector{SyntaxNode}
    @assert kind(node) == K"struct" "Expected a [struct] node, got [$(kind(node))]."
    if length(children(node)) < 2 || kind(children(node)[2]) != K"block"
        @debug "[block] not found where expected $(JS.source_location(node))." node
        return []
    end
    # Return the children of that [block] node:
    return children(children(node)[2])
end

function get_module_name(node::SyntaxNode)::NodeAndString
    @assert kind(node) == K"module" "Expected a [module] node, got [$(kind(node))]."
    @assert haschildren(node) "An empty module with no name? That can't be valid!"
    id_node = children(node)[1]
    @assert kind(id_node) == K"Identifier" """
        The first child of a [module] node is not its identifier!
    """
    return (id_node, string(id_node))
end

"""
    get_imported_pkg(node)

Return the first identifier of an imported package.

Given an `import`, `using` or `include` node, it returns the first `Identifier`
node found. Actually, it returns a tuple with that node and its textual
representation, which would be:
  * In case of an `include("path/to/Package.jl")`, it would be `Package`.
  * In case of an `import` or `using` with a `..SubModule`, the text returned by
    this function would be `SubModule`.

If there are multiple packages being imported/used, only the first one is returned.
"""
function get_imported_pkg(node::SyntaxNode)::String
    @assert is_import(node) "Expected a package import declaration, got [$(kind(node))]."
    @assert haschildren(node) "How can an [import] or [using] have nothing behind?"
    if is_include(node)
        pkg = _extract_included_file(node)
        if isnothing(pkg)
            @debug "No file name found in an [include] node $(JS.source_location(node))" node
            return ""
        end
        str = string(pkg)
        if startswith(str, '"') && endswith(str, ".jl\"")
            str = basename(str[2:end-4])
        else
            @debug "File name of submodule is not double-quotted and/or does not end with '.jl'! $(JS.source_location(node))" str
        end
    else
        pkg = children(node)[1]
        if kind(pkg) == K":" || # importing/using items from a package
           kind(pkg) == K"as"   # import with an alias
            pkg = children(pkg)[1]
        end
        @assert kind(pkg) == K"importpath"
        pkg = last(children(pkg))
        str = string(pkg)
    end
    return str
end

function _extract_included_file(included::SyntaxNode)::NullableNode
    file = children(included)[2]
    if kind(file) == K"string" return first_child(file)

    elseif kind(file) == K"call"
        ch1 = first_child(file)
        if kind(ch1) == K"Identifier" && string(ch1) == "joinpath"
            # Return the last string given to `joinpath` (the actual string is
            # the first child of that last node)
            return first_child(last(children(file)))
        end
    end
    @debug "Can't parse an 'include' $(JS.source_location(included)):" included
    return nothing
end


haschildren(node::AnyTree)::Bool = numchildren(node) > 0
children(node::AnyTree)::Vector{AnyTree} = isnothing(node.children) ?
                                                AnyTree[] : node.children
first_child(node::AnyTree)::NullableNode = haschildren(node) ?
                                                children(node)[1] : nothing


"""
Return the first left-hand side node of the given kind, going down the left-most
sub-tree in each level from the given node.
"""
function find_lhs_of_kind(node_kind::Kind, node::AnyTree)::NullableNode
    return kind(node) == node_kind ? node :
                haschildren(node) ? find_lhs_of_kind(node_kind, children(node)[1]) :
                    nothing
end

expr_depth(node::SyntaxNode)::Int = (! haschildren(node)) ? 1 :
                                        (1 + maximum(expr_depth.(children(node))))
expr_size(node::SyntaxNode)::Int = (! haschildren(node)) ? 1 :
                                        (1 + sum(expr_size.(children(node))))


"""
    get_number(node::SyntaxNode)::Union{Number, Nothing}

Get the number from a literal node, or `nothing` if it cannot be parsed.
"""
function get_number(node::SyntaxNode)::Union{Number, Nothing}
    n = Meta.parse(sourcetext(node); raise=false)
    if typeof(n) == Expr
        if n.head == :error
            @debug "Couldn't parse number from node $(node): $(n.args[1].msg)"
        else
            @debug "Expected a number, got an expression: $n"
        end
        return nothing
    end
    return n
end

"""
    get_iteration_parts(for_loop::SyntaxNode)::Tuple{NullableNode, NullableNode}

Given a [for] node, return a pair where the first part is the loop variable (it
might be a tuple, if using `enumerate`, for instance), and the second part is the
iteration expression, which can be a collection object, a call to a function like
`eachindex`, a range, etc.

If the given node is not a [for] loop, or it has an unexpected shape, then both
returned parts are `nothing` (but it is still a pair).
"""
function get_iteration_parts(for_loop::SyntaxNode)::Tuple{NullableNode, NullableNode}
    if kind(for_loop) == K"for"
        if !( haschildren(for_loop) &&
              kind(first_child(for_loop)) == K"iteration"
           )
            @debug "for loop does not have an [iteration]" for_loop
            return nothing, nothing
        end
        node = first_child(for_loop)
        if !( haschildren(node) && kind(first_child(node)) == K"in" )
            @debug "for loop does not have an [iteration]/[in] sequence:" for_loop
            return nothing, nothing
        end
        node = first_child(node)
        if numchildren(node) != 2
            @debug "for loop [iteration/in] does not have exactly two children:" for_loop
            return nothing, nothing
        end
        var, expr = children(node)
        return var, expr
    end
end

function reset_counters()
    global SOURCE_COL = 1
    global SOURCE_INDEX = 1
    global SOURCE_LINE = 1
end
function increase_counters(node::GreenNode)::Int
    global SOURCE_COL
    global SOURCE_INDEX
    global SOURCE_LINE
    if kind(node) == K"NewlineWs"
        SOURCE_LINE += 1
        SOURCE_COL = span(node) - (Sys.iswindows() ? 1 : 0)
    elseif kind(node) == K"String"
        txt = source_text(node)
        n = count('\n', txt)
        if n == 0
            SOURCE_COL += span(node)
        else
            # Occasionally, a string may contain multiple line breaks.
            SOURCE_LINE += n
            SOURCE_COL = length(txt) - last(findfirst(EOL, txt))
        end
    else
        SOURCE_COL += span(node)
    end
    SOURCE_INDEX += span(node)
end
source_text() = JS.sourcetext(SF)
function source_text(node::GreenNode, offset::Integer=0)
    start = SOURCE_INDEX + offset
    length = span(node)
    return source_text(start, length)
end
function source_text(from::Integer, howmuch::Integer)
    s = JS.sourcetext(SF)
    until = from + howmuch - 1
    if !isvalid(s, until)
        until = prevind(s, until)
    end
    return s[from:until]
end
line_breaks(node::GreenNode) = count('\n', source_text(node))
source_index() = SOURCE_INDEX
lines_count() = SOURCE_LINE
source_column() = SOURCE_COL


function to_pascal_case(s::String)::String
    result::String = ""
    got_dash::Bool = true
    for c in s
        if c ∈ ['-', '_']
            got_dash = true
        else
            result *= got_dash ? uppercase(c) : c
            got_dash = false
        end
    end
    return result
end

end
