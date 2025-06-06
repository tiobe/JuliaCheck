module ImplementUnionsAsConsts

import JuliaSyntax: SyntaxNode, @K_str, kind, children
using ...Properties: is_assignment, is_constant, is_union_decl, report_violation

function check(union::SyntaxNode)
    @assert is_union_decl(union) "Expected a Union declaration, got $(kind(union))"
    if is_assignment(union.parent) && is_constant(union.parent.parent)
        # This seems to be a Union type declaration
        if union == children(union.parent)[2]
            # Confirmed. In this case, there is nothing to report.
            return nothing
        end
    end
    report_violation(union; severity=3,
            rule_id="implement-unions-as-consts",
            user_msg="Declare this Union as a const type before using it.",
            summary="Implement Unions as const.")
end

end
