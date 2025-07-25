module LosslessTrees

using JuliaSyntax: GreenNode, SourceFile, JuliaSyntax, is_leaf

export LosslessNode,
    build_enhanced_node, build_enhanced_tree, children,
    find_nodes_by_kind, find_nodes_by_text,  # TODO Do we need this last one?
    get_ancestors, get_root,    # TODO Do we want these?
    get_source_text, get_start_coordinates,
    offset_to_line_col, print_tree, start_index


"""
Represents a span in the source code with line, column, and byte offset information.
"""
struct SourceSpan
    start_line::Int
    start_column::Int
    end_line::Int
    end_column::Int
    start_offset::Int
    end_offset::Int
end

"""
A lossless tree node that carries source location information and parent references.
Unlike GreenNode, this is not relocatable but provides full source context.
"""
mutable struct LosslessNode
    # Core node information
    kind::JuliaSyntax.Kind
    text::String  # The actual text this node represents
    span::SourceSpan  # Location information in source

    # Tree structure
    parent::Union{LosslessNode, Nothing}
    children::Vector{LosslessNode}

    # Original GreenNode reference for compatibility
    green_node::Union{GreenNode, Nothing}
    # TODO Could this be `nothing`? When/How?

    function LosslessNode(kind::JuliaSyntax.Kind, text::String, span::SourceSpan,
                          parent::Union{LosslessNode, Nothing} = nothing,
                          green_node::Union{GreenNode, Nothing} = nothing)
        node = new(kind, text, span, parent, LosslessNode[], green_node)
        return node
    end
end

"""
Add a child node to a parent, setting the parent reference.
"""
function _add_child!(parent::LosslessNode, child::LosslessNode)::LosslessNode
    push!(parent.children, child)
    child.parent = parent
    return child
end

"""
Maintains information about the source code being parsed.
"""
struct SourceContext
    source::String
    lines::Vector{String}
    line_starts::Vector{Int}  # Byte offsets where each line starts
    filename::String

    function SourceContext(source::String; file_name::String = "")
        lines = split(source, '\n')
        line_starts = Vector{Int}()
        push!(line_starts, 1)
        pos = 1
        for line in lines[1:end-1]  # All but the last line
            pos += ncodeunits(line) + 1  # +1 for newline
            push!(line_starts, pos)
        end
        new(source, lines, line_starts, file_name)
    end
end

"""
    offset_to_line_col(ctx::SourceContext, offset::Int) -> (line::Int, col::Int)

Convert a byte offset to line and column numbers (1-based).
"""
function offset_to_line_col(ctx::SourceContext, offset::Int)::Tuple{Int, Int}
    line = 1
    for i in 2:length(ctx.line_starts)
        if offset < ctx.line_starts[i]
            line = i - 1
            break
        end
        line = i
    end
    col = offset - ctx.line_starts[line] + 1
    return line, col
end
# TODO Test this one and choose
function _offset_to_line_col(ctx::SourceContext, offset::Int)::Tuple{Int, Int}
    line = length(ctx.line_starts)
    for (i, line_start) in enumerate(ctx.line_starts)
        if offset < line_start
            line = i - 1
            break
        end
    end
    col = offset - ctx.line_starts[line] + 1
    return line, col
end

"""
Create a SourceSpan from byte offsets.
"""
function _create_source_span(ctx::SourceContext,
                             start_offset::Int, end_offset::Int)::SourceSpan

    start_line, start_col = offset_to_line_col(ctx, start_offset)
    end_line, end_col = offset_to_line_col(ctx, end_offset)
    return SourceSpan(start_line, start_col,
                      end_line, end_col,
                      start_offset, end_offset)
end

"""
Build an enhanced lossless tree from a string of Julia source code.
"""
function build_enhanced_tree(source::String)::LosslessNode
    # Parse with JuliaSyntax to get the green tree
    green_tree = JuliaSyntax.parseall(GreenNode, source)
    ctx = SourceContext(source)

    # Build the enhanced tree
    root = build_enhanced_node(green_tree, ctx, 1, nothing)
    return root
end

"""
Build an enhanced lossless tree from a JuliaSyntax lossless tree and the source text.
"""
function build_enhanced_tree(green_tree::GreenNode, source::SourceFile)::LosslessNode
    ctx = SourceContext(string(JuliaSyntax.sourcetext(source));
                        file_name=source.filename)
    root = build_enhanced_node(green_tree, ctx, 1, nothing)
    return root
end

"""
Recursively build an enhanced node from a GreenNode.
"""
function build_enhanced_node(
            green::GreenNode, ctx::SourceContext,
            offset::Int, parent::Union{LosslessNode, Nothing}
        )::LosslessNode
    kind = JuliaSyntax.kind(green)
    node_length = JuliaSyntax.span(green)

    if isempty(ctx.source)
        span = SourceSpan(0, 0, 0, 0, 0, 0)
        return LosslessNode(kind, "", span, parent, green)
    end

    until = offset + node_length - 1
    if !isvalid(ctx.source, until) until = prevind(ctx.source, until) end
    text = ctx.source[offset:until]     # extract the text for this node
    span = _create_source_span(ctx, offset, until)  # create the source span

    # Create the enhanced node
    node = LosslessNode(kind, text, span, parent, green)

    # Process children
    child_offset = offset
    for child_green in children(green)
        child_node = build_enhanced_node(child_green, ctx, child_offset, node)
        _add_child!(node, child_node)
        child_offset += JuliaSyntax.span(child_green)
    end

    return node
end

# TODO Use `Properties.children`? #deps
children(node::GreenNode)::Vector{GreenNode} =
                        isnothing(node.children) ? GreenNode[] : node.children

children(node::LosslessNode)::Vector{LosslessNode} =
                    isnothing(node.children) ? LosslessNode[] : node.children

# Adapted convenience methods from JuliaSyntax

JuliaSyntax.is_leaf(node::LosslessNode)::Bool = JuliaSyntax.is_leaf(node.green_node)
JuliaSyntax.is_trivia(node::LosslessNode)::Bool = JuliaSyntax.is_trivia(kind(node))
JuliaSyntax.is_whitespace(node::LosslessNode)::Bool = JuliaSyntax.is_whitespace(node.green_node)
# haschildren(node::LosslessNode) = length(node.children) > 0
JuliaSyntax.numchildren(node::LosslessNode) = isnothing(node.children) ? 0 :
                                                length(node.children)


"""
Get all ancestors of a node, from immediate parent to root.
"""
function get_ancestors(node::LosslessNode)::Vector{LosslessNode}
    ancestors = LosslessNode[]
    current = node.parent
    while current !== nothing
        push!(ancestors, current)
        current = current.parent
    end
    return ancestors
end
# TODO Do we want this?

"""
Get the root node of the tree containing this node.
"""
function get_root(node::LosslessNode)::LosslessNode
    current = node
    while current.parent !== nothing
        current = current.parent
    end
    return current
end
# TODO Do we want this?

"""
Get the text carried by the give node.
"""
get_source_text(node::LosslessNode) = node.text

"""
Return a tuple with the line and column where the node's source begins.
"""
get_start_coordinates(node::LosslessNode) = node.span.start_line,
                                            node.span.start_column

JuliaSyntax.head(node::LosslessNode) = JuliaSyntax.head(node.green_node)
JuliaSyntax.kind(node::LosslessNode) = JuliaSyntax.kind(node.green_node)

start_index(node::LosslessNode) = node.span.start_offset
Base.length(node::LosslessNode) = length(node.text)

JuliaSyntax.span(node::LosslessNode) = node.span.end_offset

"""
Find all nodes of a specific kind in the tree.
"""
function find_nodes_by_kind(root::LosslessNode,
                            target_kind::JuliaSyntax.Kind)::Vector{LosslessNode}
    results = LosslessNode[]

    function visit(node::LosslessNode)
        if node.kind == target_kind
            push!(results, node)
        end
        for child in node.children
            visit(child)
        end
    end

    visit(root)
    return results
end

"""
Find all nodes with specific text content.
"""
function find_nodes_by_text(root::LosslessNode,
                            target_text::String)::Vector{LosslessNode}
    results = LosslessNode[]

    function visit(node::LosslessNode)
        if node.text == target_text
            push!(results, node)
        end
        for child in node.children
            visit(child)
        end
    end

    visit(root)
    return results
end

"""
Pretty print the enhanced tree structure.
"""
function print_tree(node::LosslessNode, indent::Int = 0)::Nothing
    prefix = "  " ^ indent
    span_info = "($(node.span.start_line):$(node.span.start_column)"*
                "-$(node.span.end_line):$(node.span.end_column))"
    if is_leaf(node)
        text_display = repr(node.text)
        println("$(prefix)$(node.kind) $span_info: $text_display")
    else
        println("$(prefix)$(node.kind) $span_info")
    end
    for child in node.children
        print_tree(child, indent + 1)
    end
    return nothing
end

end
