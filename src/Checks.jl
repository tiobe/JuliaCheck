module Checks

# include("../checks/check_avoid_globals.jl")
include("../checks/check_document_constants.jl")
include("../checks/check_function_arguments_in_lower_snake_case.jl")
include("../checks/check_function_identifiers_in_lower_snake_case.jl")
include("../checks/check_infinite_while_loop.jl")
include("../checks/check_leading_and_trailing_digits.jl")
include("../checks/check_long_form_functions_have_a_terminating_return_statement.jl")
include("../checks/check_module_name_casing.jl")
include("../checks/check_prefix_of_abstract_type_names.jl")
include("../checks/check_short_hand_function_too_complicated.jl")
include("../checks/check_single_module_file.jl")
# include("../checks/check_space_around_infix_operators.jl")
include("../checks/check_struct_members_are_in_lower_snake_case.jl")
include("../checks/check_too_many_types_in_unions.jl")
include("../checks/check_type_names_upper_camel_case.jl")

end
