module ModuleSingleImportLine

import JuliaSyntax: SyntaxNode, @K_str, @KSet_str, children, numchildren, kind
using ...Properties: get_imported_pkg, haschildren, is_import, is_include,
                is_upper_camel_case, report_violation

function check(modjule::SyntaxNode)
    @assert kind(modjule) == K"module" "Expected a [module] node, got [$(kind(modjule))]."
    @assert numchildren(modjule) == 2 "This module has a weird shape: "* string(modjule)
    @assert kind(children(modjule)[2]) == K"block" "The second child of a [module] node is not a [block]!"

    imports = filter(is_import, children(children(modjule)[2]))
    first_include = findfirst(is_include, imports)
    if isnothing(first_include) first_include = 1 + length(imports) end

    # First, check import's and using's (they are supposed to be contiguous, or
    # else they violate another rule)
    previous = ""
    for node in imports[1 : first_include-1]
        if numchildren(node) > 1
            report_violation(node;
                severity=9, rule_id="module-single-import-line",
                user_msg="Import only one package per line.",
                summary="Lists of imported/used packages should only specify a single package per line.")
        else
            (pkg, pkg_name) = get_imported_pkg(node)
            if pkg_name < previous
                report_violation(pkg;
                    severity=9, rule_id="module-single-import-line",
                    user_msg="Keep import/using declarations in alphabetic order.",
                    summary="The list of packages should be in alphabetic order.")
            else
                previous = pkg_name
            end
        end
    end

    # Now, we check the include's. Only their sorting (cannot include multiple
    # files at once)
    previous = ""
    for node in filter(is_include, imports[first_include : end])
        (pkg, pkg_name) = get_imported_pkg(node)
        if pkg_name < previous
            report_violation(pkg;
                severity=9, rule_id="module-single-import-line",
                user_msg="Keep import/using declarations in alphabetic order.",
                summary="The list of packages should be in alphabetic order.")
        else
            previous = pkg_name
        end
    end
end


end
