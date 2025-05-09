module FunctionIdentifiersCasing

import JuliaSyntax: SyntaxNode, @K_str, kind
using ...Properties: inside, is_lower_snake, is_struct, report_violation

function check(func_name::SyntaxNode)
    @assert kind(func_name) == K"Identifier" "Expected an [Identifier] node, got [$(kind(node))]."
    if inside(func_name, is_struct)
        # Inner constructors (functions inside a type definition) must match the
        # type's name, which must follow a different naming convention than
        # functions do, so they are excluded from this check.
        return nothing
    end
    fname = string(func_name)
    if ! is_lower_snake(fname)
        report_violation(func_name; severity=8,
                rule_id="asml-function-identifiers-in-lower-snake-case",
                user_msg="Function name `$fname` should be written in lower_snake_case.",
                summary="Function names are written in lower_snake_case.")
    end
end

end
