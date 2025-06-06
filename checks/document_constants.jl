module DocumentConstants

using JuliaSyntax: SyntaxNode, @K_str, children, kind

using ...Properties: find_first_of_kind, haschildren, report_violation

export check

function check(const_node::SyntaxNode)
    @assert kind(const_node) == K"const" "Expected a [const] const_node, got $(kind(const_node))."
    if haschildren(const_node) && kind(children(const_node)[1]) == K"="
        # This is a constant value declaration.
        assignment = children(const_node)[1]
        if haschildren(assignment)
            if kind(const_node.parent) != K"doc"
                const_id = find_first_of_kind(K"Identifier", const_node)
                report_violation(const_node; severity=7,
                        rule_id="document-constants",
                        user_msg="Const value $(string(const_id)) has no docstring.",
                        summary="Constants must have a docstring.")
            end
        else
            @debug "An assignment without children:" assignment
        end
    end
end

end
