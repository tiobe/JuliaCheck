module ModuleIncludeLocation

import JuliaSyntax: SyntaxNode, @K_str, @KSet_str, children, numchildren, kind
using ...Properties: get_imported_pkg, haschildren, is_import, is_include,
                report_violation

function check(modjule::SyntaxNode)
    @assert kind(modjule) == K"module" "Expected a [module] node, got [$(kind(modjule))]."
    @assert numchildren(modjule) == 2 "This module has a weird shape: "* string(modjule)
    @assert kind(children(modjule)[2]) == K"block" "The second child of a [module] node is not a [block]!"

    mod_body = children(children(modjule)[2])
    code_beginning = findfirst(!is_import, mod_body)
    if code_beginning === nothing
        # No code, only imports. It usually happens in packages "entry" files.
        code_beginning = length(mod_body) + 1
    end
    includes_start = findfirst(is_include, mod_body[1:code_beginning-1])
    if includes_start !== nothing
        for (i, node) in enumerate(mod_body[includes_start+1 : code_beginning-1])
            if !is_include(node)
                # It must be an [import] or [using]
                previous = mod_body[includes_start + i - 1]
                imported_module = get_imported_pkg(node)
                included_pkg = get_imported_pkg(previous)
                if !is_include(previous) || last(imported_module) != last(included_pkg)
                    report_violation(node;
                        severity=9, rule_id="module-include-location",
                        user_msg="Group include's after all import/using lines.",
                        summary="The list of included files appears after the list of imported packages.")
                end
            end
        end
    end
end


end
