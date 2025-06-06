module StructMembersAreInLowerSnakeCase

import JuliaSyntax: SyntaxNode, @K_str, kind, children
using ...Properties: find_first_of_kind, is_lower_snake, report_violation

function check(field::SyntaxNode)
    @assert kind(field.parent) == K"block" &&
            kind(field.parent.parent) == K"struct"  "Expected a node representing" *
                        " a field (child of a [struct])" field.parent
    if kind(field) == K"function"
        # This is not a field really, but an inner constructor (a function
        # inside a type definition), which must match the type's name, which
        # must follow a different naming convention than functions do.
        return nothing
    end
    field_name = find_first_of_kind(K"Identifier", field)
    if !is_lower_snake(string(field_name))
        report_violation(field_name; severity=8,
                rule_id="struct-members-are-in-lower-snake-case",
                user_msg="Field '$(string(field_name))' should be written in lower_snake_case.",
                summary="Struct members are implemented in lower_snake_case.")
    end
end


end
