module Properties

import JuliaSyntax: Kind, GreenNode, SyntaxNode, SourceFile, @K_str, @KSet_str,
    children, head, kind, span, untokenize, JuliaSyntax as JS

export AnyTree, MAX_LINE_LENGTH, opens_scope, closes_module, closes_scope,
    haschildren, increase_counters, is_abstract, is_assignment, is_constant,
    is_function, is_import, is_include, is_infix_operator, is_loop, is_literal,
    is_lower_snake, is_module, is_operator, is_struct, is_toplevel, is_type_op,
    is_union_decl, is_upper_camel_case, expr_depth, expr_size, find_first_of_kind,
    get_assignee, get_func_arguments, get_func_body, get_func_name, get_imported_pkg,
    get_module_name, get_struct_members, get_struct_name, lines_count, report_violation,
    reset_counters, SF, source_column, source_index, source_text


## Types
const AnyTree = Union{SyntaxNode, GreenNode}


## Global definitions
global SF::SourceFile
SOURCE_INDEX = 0
SOURCE_LINE = 0
SOURCE_COL = 0
const MAX_LINE_LENGTH = 92


## Functions

function report_violation(node::SyntaxNode;
                          severity::Int, user_msg::String,
                          summary::String, rule_id::String)
    line, column = JS.source_location(node)
    printstyled("\n$(JS.filename(node))($line, $(column)):\n";
                underline=true)
    JS.highlight(stdout, node; note=user_msg, notecolor=:yellow,
                               context_lines_after=0, context_lines_before=0)
    _report_common(severity, rule_id, summary)
end
function report_violation(; index::Int, len::Int, line::Int, col::Int,
                            severity::Int, user_msg::String,
                            summary::String, rule_id::String)
    printstyled("\n$(JS.filename(SF))($line, $col):\n";
                underline=true)
    JS.highlight(stdout, SF, index:index+len-1;
                 note=user_msg, notecolor=:yellow,
                 context_lines_after=0, context_lines_before=0)
    _report_common(severity, rule_id, summary)
end
function _report_common(severity::Int, rule_id::String, summary::String)
    printstyled("\n$summary"; color=:cyan)
    printstyled("\nRule:"; underline=true)
    printstyled(" $rule_id. ")
    printstyled("Severity:"; underline=true)
    printstyled(" $severity\n")
end


function haschildren(node::AnyTree)
    subnodes = children(node)
    return (! isnothing(subnodes)) && length(subnodes) > 0
end

function is_lower_snake(s::AbstractString)
    return isnothing(match(r"[[:upper:]]", s))
end
function is_upper_camel_case(s::AbstractString)
    m = match(r"([[:upper:]][[:lower:][:digit:]]+)+", s)
    return !isnothing(m) && length(m.match) == length(s)
end


is_toplevel(  node::AnyTree) = kind(node) == K"toplevel"
is_module(    node::AnyTree) = kind(node) == K"module"
is_assignment(node::AnyTree) = kind(node) == K"="
is_literal(   node::AnyTree) = kind(node) in KSet"Float Integer"
is_function(  node::AnyTree) = kind(node) == K"function"
is_struct(    node::AnyTree) = kind(node) == K"struct"
is_abstract(  node::AnyTree) = kind(node) == K"abstract"
is_loop(      node::AnyTree) = kind(node) in KSet"while for"
is_constant(  node::AnyTree) = kind(node) == K"const"

function is_union_decl(node::SyntaxNode)
    if kind(node) == K"curly" && haschildren(node)
        first_child = children(node)[1]
        return kind(first_child) == K"Identifier" && string(first_child) == "Union"
    end
    return false
end

function is_operator(node::AnyTree)
    return  JS.is_prefix_op_call(node) ||
    is_infix_operator(node)  ||
    JS.is_postfix_op_call(node)
end
function is_infix_operator(node::AnyTree)
    return JS.is_infix_op_call(node) || JS.is_operator(node)
end

is_type_op(node::AnyTree) = kind(node) in KSet":: <: >:"

function is_include(node::AnyTree)
    if kind(node) == K"call" && haschildren(node)
        id = children(node)[1]
        return kind(id) == K"Identifier" && string(id) == "include"
    end
    return false
end
is_import(node::AnyTree) = kind(node) in KSet"import using" || is_include(node)


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


function get_func_name(node::SyntaxNode)
    @assert is_function(node) "Expected a [function] node, got [$(kind(node))]."
    fname = find_first_of_kind(K"Identifier", node)
    if isnothing(fname)
        @debug "Unprocessed corner case:" node
        return nothing
    end
    if  kind(fname.parent) == K"."  # In this case, the 1st child is a module name
        fname = children(fname.parent)[2]
    end
    if kind(fname) == K"quote"  # Overloading an operator, which comes next
        fname = children(fname)[1]
    end
    return fname
end

function get_func_arguments(node::SyntaxNode)
    @assert is_function(node) "Expected a [function] node, got [$(kind(node))]."
    call = find_first_of_kind(K"call", children(node)[1])
    if isnothing(call)
        @debug "No [call] node found for a [function] node:\n" node
        return []
    end
    return children(call)[2:end]    # discard the function's name (1st identifier in this list)
end

function get_func_body(node::SyntaxNode)
    @assert is_function(node) "Expected a [function] node, got [$(kind(node))]."
    if ! haschildren(node) || length(children(node)) < 2
        @debug "Strange function node. Cannot return its body." node
        return nothing
    end
    return children(node)[2]
end


function get_assignee(node::SyntaxNode)
    @assert kind(node) == K"=" "Expected a [=] node, got [$(kind(node))]."
    children(node)[1]   # FIXME
end


function get_struct_name(node::SyntaxNode)
    @assert kind(node) == K"struct" "Expected a [struct] node, got [$(kind(node))]."
    return find_first_of_kind(K"Identifier", node)
end

function get_struct_members(node::SyntaxNode)
    @assert kind(node) == K"struct" "Expected a [struct] node, got [$(kind(node))]."
    if length(children(node)) < 2 || kind(children(node)[2]) != K"block"
        @debug "[block] not found where expected." node
        return nothing
    end
    # Return the children of that [block] node:
    return children(children(node)[2])
end

function get_module_name(node::SyntaxNode)
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

Given an [import] or [using] node, it returns the first [Identifier] node found.
Use `string` function to extract the text contained therein.

If there are multiple packages being imported/used, only the first one is returned.
"""
function get_imported_pkg(node::SyntaxNode)
    @assert is_import(node) "Expected a package import declaration, got [$(kind(node))]."
    @assert haschildren(node) "How can an [import] or [using] have nothing behind?"
    local pkg::SyntaxNode
    if is_include(node)
        pkg = children(node)[2]
    else
        pkg = children(node)[1]
        if kind(pkg) == K":"    # importing/using items from a package
            pkg = children(pkg)[1]
        end
        @assert kind(pkg) == K"importpath"
        pkg_pos = findfirst(x -> kind(x) != K".", children(pkg))
        @assert pkg_pos !== nothing
        pkg = children(pkg)[pkg_pos]
    end
    return pkg
end


function find_first_of_kind(node_kind::Kind, node::AnyTree)
    child = node
    while kind(child) != node_kind && haschildren(child)
        child = children(child)[1]
    end
    return kind(child) == node_kind ? child : nothing
end

expr_depth(node::SyntaxNode) = (! haschildren(node)) ? 1 :
                                    (1 + maximum(expr_depth.(children(node))))
expr_size(node::SyntaxNode) = (! haschildren(node)) ? 1 :
                                    (1 + sum(expr_size.(children(node))))


function reset_counters()
    global SOURCE_COL = 1
    global SOURCE_INDEX = 1
    global SOURCE_LINE = 1
end
function increase_counters(node::GreenNode)
    global SOURCE_COL
    global SOURCE_INDEX
    global SOURCE_LINE
    if kind(node) == K"NewlineWs"
        SOURCE_LINE += SOURCE_COL = 1
    elseif kind(node) == K"String"
        txt = source_text(node)
        n = count(r"\n", txt)
        SOURCE_LINE += n
        if n > 0
            if n > 1
                @debug "String with $n line breaks:" txt    # TODO Delete me!
            end
            SOURCE_COL = length(txt) - findlast('\n', txt)
        end
    else
        SOURCE_COL += span(node)
    end
    SOURCE_INDEX += span(node)
end
source_text() = JS.sourcetext(SF)
function source_text(node::GreenNode, offset::Integer=0)
    start = SOURCE_INDEX + offset
    length = span(node) - 1
    return source_text(start, length)
end
source_text(from::Integer, howmuch::Integer) = JS.sourcetext(SF)[from : from+howmuch]
line_breaks(node::GreenNode) = count(r"\n", source_text(node))
source_index() = SOURCE_INDEX
lines_count() = SOURCE_LINE
source_column() = SOURCE_COL


end
