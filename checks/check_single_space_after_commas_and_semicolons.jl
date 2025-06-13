module SingleSpaceAfterCommasAndSemicolons

import JuliaSyntax: GreenNode, SyntaxNode, @K_str, haschildren, is_whitespace,
    kind, children, span

using ...Properties: EOL, fake_green_node, is_separator, lines_count,
    report_violation, source_column, source_index, source_text


# Global / static variable
CHECKED::Vector{Int} = []

reset() = global CHECKED = []

function check(node::GreenNode, parent::GreenNode)
    @assert is_separator(node) "Expected a [;] or [,] node, but got a node of kind $(kind(node))"
    global CHECKED
    if isempty(CHECKED) || last(CHECKED) < source_index()
        # Find which child of 'parent' is the 'node'.
        function same_kind(x)
            return kind(x) == kind(node)
        end
        expr = children(parent)
        op_node = findfirst(same_kind, expr)
        if isnothing(op_node)
            @debug "Operator token not found inside operator expression subtree." parent
            return nothing
        end
        # Get global offset at which 'parent' is.
        offset_in_expr = sum(span.(expr[1:op_node]))
        parent_index = source_index() - offset_in_expr
        parent_column = source_column() - offset_in_expr    # FIXME will only work while in same line as beginning of expression
        # Add to the list the index at which the parent expression ends, so we
        # won't check any more of its children.
        push!(CHECKED, (parent_index + span(parent)))
        # Then, proceed to check all its relevant children.
        check(parent, parent_index, parent_column, findall(is_separator, expr))
    end
end

function report_it(offset::UInt, length::UInt, src_line::Int, src_col::UInt)
    report_violation(index=offset, len=length, line=src_line, col=src_col,
        severity=7,
        rule_id="asml-single-space-after-commas-and-semicolons",
        user_msg="A comma or a semicolon is followed, but not preceded, by a space.",
        summary="Commas and semicolons are followed, but not preceded, by a space.")
end

function check(parent::GreenNode, parent_index::UInt, parent_col::UInt,
    separators::Vector{Int})
    report(x, y, a) = report_it(parent_index + x, convert(UInt, y),
        lines_count() + a, parent_col + x)
    # FIXME Add an argument with the right column offset, which is the same as
    # x if there are no line breaks in the span[1:i], but has to be figured out
    # otherwise, probably finding the latest \n (or EOL) and finding the length
    # from there.

    expr = children(parent)
    for i in separators
        before = i == 1 ? fake_green_node(K"(") : expr[i-1]
        after = i == length(expr) ? fake_green_node(K")") : expr[i+1]
        offset = sum(span.(expr[1:i]))
        ln_breaks = count('\n', source_text(parent_index, offset))

        if is_whitespace(before)
            len = span(before)
            report(offset - len, len, ln_breaks)
        end

        if haschildren(after) && is_whitespace(children(after)[1])
            after = children(after)[1]
        end

        if !is_whitespace(after)
            report(offset + 1, 0, ln_breaks)

        elseif span(after) > 1
            # There should be only one space...
            len = span(after)
            offset += 1
            if kind(after) == K"NewlineWs"
                # ... unless it is a line break (followed by indentation)
                textual = source_text(parent_index + offset, len)
                line_break = Regex("$EOL[ \t]*")
                if occursin(line_break, textual)
                    len = offset = 0  # reset to deactivate the report
                end
            end
            if offset > 0
                report(offset, len, ln_breaks)
            end
        end

    end
end

end
