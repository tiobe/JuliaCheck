module UseIsnanToCheckForNan

import JuliaSyntax: SyntaxNode, GreenNode, @K_str, @KSet_str, children, kind,
                numchildren, span, untokenize
using ...Properties: NullableString, find_first_of_kind, get_assignee,
                haschildren, report_violation

SEVERITY = 3
RULE_ID="use-isnan-to-check-for-nan"
USER_MSG = "Use isnan to check for not-a-number values."
SUMMARY = "Use isnan to check variables for not-a-number."

"""
    check(node::SyntaxNode)

Report if a direct comparison is made with NaN (of any size).
"""
function check(node::SyntaxNode)::Nothing
    inf_type = extract_nan_type(node)
    if inf_type !== nothing
        report_violation(node; severity = SEVERITY, rule_id = RULE_ID,
                               user_msg = USER_MSG, summary = SUMMARY)
    end
end

function extract_nan_type(node::SyntaxNode)::NullableString
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
        if value ∈ ("NaN", "NaN16", "NaN32", "NaN64")
            return sign * value
        end
    end

    return nothing
end


end # module UseIsnanToCheckForNan
