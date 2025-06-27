module GlobalVariablesUpperSnakeCase

using JuliaSyntax: SyntaxNode, @K_str, children, kind
using ...Checks: is_enabled
using ...Properties: is_fat_snake_case, get_assignee, report_violation

const RULE_ID = "asml-global-variables-upper-snake-case"
const SUMMARY = USER_MSG = "Casing of globals."
SEVERITY = 3

function check(glob_var::SyntaxNode)
    if !is_enabled(RULE_ID) return nothing end

    @assert kind(glob_var) == K"Identifier" "Expected an [Identifier] node (assignment), got [$(kind(glob_var))]."
    var_name = string(glob_var)
    if !is_fat_snake_case(var_name)
        report_violation(glob_var; severity = SEVERITY, rule_id = RULE_ID,
            user_msg = "Variable $var_name should be written in UPPER_SNAKE_CASE.",
            summary = SUMMARY)
    end
end

end
