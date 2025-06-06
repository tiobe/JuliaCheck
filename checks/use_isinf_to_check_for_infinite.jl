module UseIsinfToCheckForInfinite

import JuliaSyntax: SyntaxNode, GreenNode, @K_str, @KSet_str, children, kind,
                numchildren, span, untokenize
using ...Properties: NullableString, find_first_of_kind, haschildren,
                report_violation

"""
    check(node::SyntaxNode)

Report if a check for infinity is done by direct comparison.
"""
function check(node::SyntaxNode)::Nothing
    inf_type = extract_inf_type(node)
    if inf_type !== nothing
        report_violation(node;
            severity=3, rule_id="use-isinf-to-check-for-infinite",
            user_msg = "Detected comparison with $inf_type.",
            summary = "Use isinf to check for infinite values.")
    end
end

function extract_inf_type(node::SyntaxNode)::NullableString
    sign = ""
    if kind(node) == K"call" && numchildren(node) > 1
        first, second = children(node)[1:2]
        if kind(first) == K"Identifier" && string(first) ∈ ("-", "+")
            if string(first) == "-" sign = "-" end
            node = second
        end
    end

    if kind(node) == K"." && length(children(node)) >= 2
        # For qualified names like Base.Inf, return just the Inf part
        node = last(children(node))
    end

    if kind(node) == K"Identifier"
        value = string(node)
        if value ∈ ("Inf", "Inf16", "Inf32", "Inf64")
            return sign * value
        end
    end

    return nothing
end


end # module UseIsinfToCheckForInfinite
