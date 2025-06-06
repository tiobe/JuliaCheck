module Checks

using ..Properties: to_pascal_case

export check, setup_filter

# Global repo of rules
RULES::Vector{String} = []

function setup_filter(rules::Vector{String})
    global RULES = rules
end

function check(rule_id::String, node...)
    if isempty(RULES) || rule_id ∈ RULES
        func = eval(Meta.parse("$(to_pascal_case(rule_id)).check"))
        return func(node...)
    end
end

# include("../checks/avoid_global_variables.jl")
include("../checks/document_constants.jl")
include("../checks/do_not_set_variables_to_nan.jl")
include("../checks/do_not_set_variables_to_inf.jl")
include("../checks/function_identifiers_in_lower_snake_case.jl")
include("../checks/function_arguments_in_lower_snake_case.jl")
include("../checks/indentation_levels_are_four_spaces.jl")
include("../checks/implement_unions_as_consts.jl")
include("../checks/infinite_while_loop.jl")
include("../checks/leading_and_trailing_digits.jl")
include("../checks/long_form_functions_have_a_terminating_return_statement.jl")
include("../checks/module_end_comment.jl")
include("../checks/module_import_location.jl")
include("../checks/module_include_location.jl")
include("../checks/module_name_casing.jl")
include("../checks/module_single_import_line.jl")
include("../checks/no_whitespace_around_type_operators.jl")
include("../checks/prefix_of_abstract_type_names.jl")
include("../checks/short_hand_function_too_complicated.jl")
include("../checks/single_module_file.jl")
# include("../checks/space_around_infix_operators.jl")
include("../checks/struct_members_are_in_lower_snake_case.jl")
include("../checks/too_many_types_in_unions.jl")
include("../checks/type_names_upper_camel_case.jl")
include("../checks/use_spaces_instead_of_tabs.jl")
include("../checks/use_isinf_to_check_for_infinite.jl")
include("../checks/use_ismissing_to_check_for_missing_values.jl")
include("../checks/use_isnan_to_check_for_nan.jl")
include("../checks/use_isnothing_to_check_for_nothing_values.jl")

end
