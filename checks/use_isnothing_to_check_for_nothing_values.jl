module UseIsnothingToCheckForNothingValues

import JuliaSyntax: SyntaxNode, GreenNode, @K_str, @KSet_str, children, kind,
                numchildren, span, untokenize
using ...Properties: NullableString, find_first_of_kind, get_assignee,
                haschildren, report_violation

"""
    check(node::SyntaxNode)

Report if a check for nothing is done by direct comparison.
"""
function check(node::SyntaxNode)::Nothing
    nothing_type = extract_nothing_type(node)
    if nothing_type !== nothing
        report_violation(node;
            severity=3, rule_id="use-isnothing-to-check-for-nothing-values",
            user_msg = "Detected comparison with $nothing_type.",
            summary = "Use isnothing to check for nothing values.")
    end
end

function extract_nothing_type(node::SyntaxNode)::NullableString
    if kind(node) == K"." && length(children(node)) >= 2
        # For qualified names like Base.nothing, return just the nothing part
        node = last(children(node))
    end

    if kind(node) == K"Identifier" && string(node) ∈ ("nothing","Nothing")
        return string(node)
    end

    return nothing
end


end # module UseIsnothingToCheckForNothingValues
