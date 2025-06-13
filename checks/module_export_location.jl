module ModuleExportLocation

import JuliaSyntax: SyntaxNode, @K_str, @KSet_str, children, numchildren, kind
using ...Properties: get_imported_pkg, haschildren, is_export, is_import,
                    is_include, report_violation

no_ex_imports(node::SyntaxNode) = ! (is_import(node) || is_export(node))

function check(modjule::SyntaxNode)
    @assert kind(modjule) == K"module" "Expected a [module] node, got [$(kind(modjule))]."
    @assert numchildren(modjule) == 2 "This module has a weird shape: "* string(modjule)
    @assert kind(children(modjule)[2]) == K"block" "The second child of a [module] node is not a [block]!"

    mod_body = children(children(modjule)[2])
    last_export = findlast(is_export, mod_body)
    if last_export === nothing return nothing end

    code_begin = findfirst(no_ex_imports, mod_body)
    if code_begin === nothing
        # Nothing to check that is not yet covered by other rules.
        return nothing
    end

    for node in filter(is_export, mod_body[code_begin:end])
        report_violation(node;
            severity=9, rule_id="module-export-location",
            summary="Location of exported functions and exported structs.",
            user_msg="Exports should be implemented after the include instructions.")
    end
end


end
