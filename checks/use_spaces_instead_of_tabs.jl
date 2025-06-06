module UseSpacesInsteadOfTabs

import JuliaSyntax: GreenNode, SourceFile, @K_str, kind, children, span
using ...Properties: lines_count, report_violation, source_index, source_text

function check(node::GreenNode)
    if kind(node) != K"NewlineWs"
        return nothing
    end
    textual = source_text(node)
    match = findfirst("\t", textual)
    if match !== nothing
        report_violation(index = source_index() + match.start - 1,
                         line = lines_count() + 1,
                         col = match.start - 1,
                         len=1, severity=7,
                         rule_id="use-spaces-instead-of-tabs",
                         user_msg="There are tab characters here.",
                         summary="Use spaces instead of tabs for indentation.")
    end
end


end
