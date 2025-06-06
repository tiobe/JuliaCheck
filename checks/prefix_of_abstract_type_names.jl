module PrefixOfAbstractTypeNames

import JuliaSyntax: SyntaxNode, @K_str, kind, children
using ...Properties: find_first_of_kind, is_upper_camel_case, report_violation

function check(user_type::SyntaxNode)
    @assert kind(user_type) == K"abstract"  "Expected an [abstract] node, got $(kind(user_type))"
    type_id = find_first_of_kind(K"Identifier", user_type)
    @assert type_id !== nothing "Got a type declaration without name (identifier)."
    type_name = string(type_id)
    if ! is_upper_camel_case(type_name)
        report_violation(type_id; severity=3, rule_id="type-names-upper-camel-case",
                user_msg="Type names such as $type_name should be written in Upper Camel Case.",
                summary="Type names in UpperCamelCase.")
    end
    if ! startswith(type_name, "Abstract")
        report_violation(type_id; severity=4, rule_id="prefix-of-abstract-type-names",
                user_msg="Abstract type names like $type_name should have prefix \"Abstract\".",
                summary="Abstract type names are prefixed by \"Abstract\".")
    end
end

end
