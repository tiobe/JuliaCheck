module ModuleEndComment

import JuliaSyntax: @K_str, kind
using ...Checks: is_enabled
using ...Properties: NullableNode, report_violation
using ...LosslessTrees: LosslessNode, children, get_source_text

const SEVERITY = 9
const RULE_ID = "module-end-comment"
const USER_MSG = "The end statement of module has a comment with the module name."
const SUMMARY = "The \"end\" of a module quotes the module name in a comment."


function check(node::LosslessNode)::Nothing
    if !is_enabled(RULE_ID) return nothing end

    @assert kind(node) == K"end" "Expected an [end] node, got [$(kind(node))]."
    if kind(node.parent) != K"module" return nothing end

    mod = node.parent
    module_siblings = children(mod.parent)
    pos = findfirst(x -> x === mod, module_siblings)
    @assert pos !== nothing "This [module] node does not seem to be child of its parent!"
    # Whose child is it, then? Julio Iglesias? Jonathan M.?

    mod_name = get_module_name(mod)
    if isnothing(mod_name)
        @debug "Couldn't find module's name." node
        return nothing
    end

    if pos < length(module_siblings)
        next = module_siblings[pos + 1]
        if kind(next) == K"Whitespace" && pos + 1 < length(module_siblings)
            next = module_siblings[pos + 2]
        end
        if kind(next) == K"Comment"
            comment = get_source_text(next)
            if matches_module_name(mod_name, comment)
                return nothing  # it's good!
            end
        end
    end
    # Either no comment found, or not in the same line as the [end] (that is
    # not considered OK), or the comment didn't match the expected content.
    report_violation(node; severity = SEVERITY, rule_id = RULE_ID,
                           user_msg = USER_MSG, summary = SUMMARY)
end

function get_module_name(mod::LosslessNode)::NullableNode
    kids = children(mod)
    if kind(kids[3]) == K"Identifier" return kids[3] end
    for k in kids
        if kind(k) == K"Identifier" return k end
    end
    return nothing
end

function matches_module_name(mod_name::LosslessNode, comment::AbstractString)
    return occursin(Regex("(module[ ]+)?" * mod_name.text), comment)
end

end
