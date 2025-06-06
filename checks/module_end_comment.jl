module ModuleEndComment

import JuliaSyntax: SyntaxNode, GreenNode, @K_str, children, kind,
        first_byte, last_byte, span

using ...Properties: find_first_of_kind, haschildren, is_upper_camel_case,
        get_module_name, lines_count, report_violation, source_column,
        source_index, source_text

function check(modjule::SyntaxNode)::Nothing
    @assert kind(modjule) == K"module" "Expected a [module] node, got [$(kind(modjule))]."
    above = modjule.parent.raw
    pos = findfirst(x -> x === modjule.raw, children(above))
    @assert pos !== nothing "This [module] node does not seem to be child of its parent!"
    # Whose child is it, then? Julio Iglesias? Jonathan M.?

    very_last = last(children(above))
    if modjule !== very_last
        (mod_name_node, mod_name_str) = get_module_name(modjule)
        comment_index = last_byte(modjule) + 1
        next = children(above)[pos + 1]
        if kind(next) == K"Whitespace" && next !== very_last
            comment_index += span(next)
            next = children(above)[pos + 2]
        end
        if kind(next) == K"Comment"
            comment = source_text(comment_index, span(next))
            if matches_module_name(mod_name_str, comment)
                return nothing  # it's good!
            end
        end
    end
    # Either no comment found, or not in the same line as the [end] (that is
    # not considered OK), or the comment didn't match the expected content.
    report_violation(mod_name_node; severity=9, rule_id="module-end-comment",
        user_msg="The 'end' statement of this module should have a comment with the module's name.",
        summary="The end of a module quotes the module name in a comment.")
    # TODO report on the 'end' keyword, not on the 'module'.
end

function matches_module_name(mod_name::AbstractString, comment::AbstractString)
    return occursin(Regex("(module[ ]+)?" * mod_name), comment)
end

end
