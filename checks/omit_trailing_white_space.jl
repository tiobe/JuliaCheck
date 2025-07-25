module OmitTrailingWhiteSpace

import JuliaSyntax: @K_str, @KSet_str, kind
using ...Checks: is_enabled
using ...Properties: EOL, lines_count, report_violation, source_text
using ...LosslessTrees: LosslessNode, get_source_text, get_start_coordinates,
                        start_index

const SEVERITY = 7
const RULE_ID = "omit-trailing-white-space"
const USER_MSG = "Omit spaces at the end of a line."
const SUMMARY = "Omit trailing whitespace."

function check(node::LosslessNode)
    if !is_enabled(RULE_ID) return nothing end
    if kind(node) ∉ KSet"NewlineWs String Comment" return nothing end

    function report(p::Integer)::Nothing
        y, x = get_start_coordinates(node)
        report_violation(index = start_index(node) + p, len = 0,
                         line = y, col = x,
                         severity = SEVERITY, rule_id = RULE_ID,
                         user_msg = USER_MSG, summary = SUMMARY)
    end

    textual = get_source_text(node)
    if kind(node) == K"NewlineWs"
        if startswith(textual, ' ') || startswith(textual, '\t')
            report(first(findfirst(EOL, textual)) - length(EOL))
        end

    elseif kind(node) == K"String"
        if endswith(textual, " $EOL") || endswith(textual, "\t$EOL")
            report(length(textual) - length(EOL))
        end

    else    # kind is Comment
        if endswith(textual, ' ') || endswith(textual, '\t')
            report(length(textual))
        end
    end
end

end
