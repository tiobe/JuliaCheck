module SpaceAroundInfixOperators

using JuliaSyntax: SyntaxNode, @K_str, @KSet_str, children, kind, is_whitespace,
    span, untokenize, JuliaSyntax as JS

using ...Properties: report_violation

export check

function check(op_call::SyntaxNode)
    # @debug "\n" op_call
    # @debug "\n" op_call.raw

    # In the general case, we want (only) one space on either side of the operator,
    # while in the exceptional cases (type operators TODO:?and within brackets?),
    # we want the reverse condition: no spaces on neither side of the operator.
    exceptional = kind(op_call) == K"::"  # Exceptions
    meets_criteria = _get_criteria(exceptional)

    op_index = findfirst(x -> kind(x) == kind(op_call), children(op_call.raw))
    if isnothing(op_index)
        @error "No operator found among the children of the given node:\n" op_call
        return nothing
    end
    (lhs, rhs) = _get_op_surrounds(op_call, op_index)
    if !( meets_criteria(lhs) && meets_criteria(rhs) )
        report_violation(op_call, "Bad format around operator",
            "There should be " * (
                exceptional ? "no spaces around that operator."
                    : "exactly one space on either side of that operator."
            )
        )
    end
end

function _get_criteria(is_exception::Bool)
    return is_exception ? (x -> !is_whitespace(x)) :
                          (x -> is_whitespace(x) && (kind(x) == K"NewlineWs" ||
                                                     span(x) == 1))
end

function _get_op_surrounds(op_call::SyntaxNode, op_pos::Int)
    parts = children(op_call.raw)
    (lhs, rhs) = (parts[op_pos-1], parts[op_pos+1])
    if !is_whitespace(rhs)
        while kind(rhs) == K"call"
            # Look at the 1st child of the RHS expression for that whitespace
            rhs = children(rhs)[1]
        end
    end
    return (lhs, rhs)
end

end
