module ModuleNameCasing

import JuliaSyntax: SyntaxNode, @K_str, children, kind
using ...Properties: get_module_name, haschildren, is_upper_camel_case, report_violation

function check(modjule::SyntaxNode)
    @assert kind(modjule) == K"module" "Expected a [module] node, got [$(kind(modjule))]."
    (mod_id_node, mod_id_str) = get_module_name(modjule)
    if ! is_upper_camel_case(mod_id_str)
        report_violation(mod_id_node; severity=5, rule_id="module-name-casing",
                user_msg="Module name `$mod_id_str` should be written in UpperCamelCase.",
                summary="Package and module names should be written in UpperCamelCase.")
    end
end

end
