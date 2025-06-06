module UseIsmissingToCheckForMissingValues

import JuliaSyntax: SyntaxNode, GreenNode, @K_str, @KSet_str, children, kind,
                numchildren, span, untokenize
using ...Properties: NullableString, find_first_of_kind, numchildren,
                haschildren, report_violation

"""
    check(node::SyntaxNode)

Report if a check for missing value is done by direct comparison.
"""
function check(node::SyntaxNode)::Nothing
    missing_type = extract_missing_type(node)
    if missing_type !== nothing
        report_violation(node;
            severity=3, rule_id="use-ismissing-to-check-for-missing-values",
            user_msg = "Detected comparison with $missing_type.",
            summary = "Use ismissing to check for missing values.")
    end
end

function extract_missing_type(node::SyntaxNode)::NullableString
    if kind(node) == K"." && length(children(node)) >= 2
        # For qualified names like Base.Inf, return just the Inf part
        node = last(children(node))
    end

    if kind(node) == K"Identifier" && string(node) ∈ ("Missing", "missing")
        return string(node)
    end

    return nothing
end


end # module UseIsmissingToCheckForMissingValues
