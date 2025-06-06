module TypeNamesUpperCamelCase

import JuliaSyntax: SyntaxNode, @K_str, kind, children
using ...Properties: find_first_of_kind, is_upper_camel_case, report_violation

function check(user_type::SyntaxNode)
    @assert kind(user_type) == K"struct"  "Expected a [struct] node, got $(kind(user_type))"
    type_name = find_first_of_kind(K"Identifier", user_type)
    if ! is_upper_camel_case(string(type_name))
        report_violation(type_name; severity=3,
                rule_id="type-names-upper-camel-case",
                user_msg="Type names such as $(string(type_name)) should be written in Upper Camel Case.",
                summary="Type names in UpperCamelCase.")
    end
end

end
