module ShortHandFunctionTooComplicated

using JuliaSyntax: SyntaxNode, @K_str, char_range, kind, sourcetext

using ...Properties: MAX_LINE_LENGTH, expr_depth, expr_size, get_func_name,
    report_violation

export check

function check(node::SyntaxNode)
    if kind(node) == K"block"
        # It's a full-form function, so no check to do.
        return nothing
    end
    func = node.parent
    report() = report_violation(node; severity=3,
        rule_id="short-hand-function-too-complicated",
        user_msg="Function '$(get_func_name(func))' is too complex for the shorthand notation; use keyword 'function'.",
        summary="Short-hand notation with concise functions.")

    line_len = length(sourcetext(func))
    if line_len > MAX_LINE_LENGTH
        @debug "Line length exceeded." line_len
        report()
    elseif line_len > round(Int, 0.9 * MAX_LINE_LENGTH)
        # The line doesn't exceed the hard length limit, but it's long enough
        # to inspect the "size" of the function definition expression: if the
        # depth is higher than a given limit, or the full size (total number
        # of nodes in the tree) exceeds another limit, we report it, too.
        if expr_depth(node) > 4 || expr_size(node) > 10
            report()
        end
    end
    return nothing
end

end
