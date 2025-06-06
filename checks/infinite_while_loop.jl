module InfiniteWhileLoop

import JuliaSyntax: SyntaxNode, @K_str, kind, children
using ...Properties: haschildren, report_violation

function check(wyle::SyntaxNode)
    @assert kind(wyle) == K"while" "Expected a [while], got $(kind(wyle))"
    @assert haschildren(wyle) "A [while] without children! Is this an incomplete tree, from code under edition?"
    condition = children(wyle)[1]
    if kind(condition) == K"Bool" && string(condition) == "true"
        report_violation(condition; severity=5,
                rule_id="infinite-while-loop",
                user_msg= "Implement a proper stop criterion for this while loop.",
                summary="Do not use while true.")
    end
end


end
