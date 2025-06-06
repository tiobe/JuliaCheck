module TooManyTypesInUnions

import JuliaSyntax: SyntaxNode, @K_str, kind, children
using ...Properties: is_union_decl, report_violation

function check(union_decl::SyntaxNode)
    @assert is_union_decl(union_decl) "Expected a Union declaration, got $(kind(union_decl))"
    union_types = children(union_decl)[2:end] # discard the 1st, which is "Union"
    if length(union_types) > 4
        report_violation(union_decl; severity=6,
                rule_id="too-many-types-in-unions",
                user_msg="Detected a union with too many types.",
                summary="Too many types: there should be no more than 4 types in a Union.")
    end
end

end
