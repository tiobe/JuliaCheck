module Process

import JuliaSyntax: SyntaxNode, SourceFile, ParseError, @K_str, is_leaf,
                    is_whitespace, kind, numchildren, JuliaSyntax as JS

using ..Properties
using ..LosslessTrees: LosslessNode, build_enhanced_tree, print_tree
import ..Checks
include("SymbolTable.jl"); import .SymbolTable

export check

global const trivia_checks_enabled = true


function check(file_name::String;
               print_ast::Bool = false, print_llt::Bool = false)
    Properties.SF = SourceFile(; filename=file_name)
    ast = parse(SF)
    if isnothing(ast)
        @error "Couldn't parse file '$file_name'"
    else
        if print_ast
            show(stdout, MIME"text/plain"(), ast)
        end
        if print_llt
            show(stdout, MIME"text/plain"(), ast.raw, string(JS.sourcetext(SF)))
            # print_tree(build_enhanced_tree(ast.raw, SF))
        end

        SymbolTable.enter_main_module!()
        process(ast)
        if trivia_checks_enabled
            process_with_trivia(build_enhanced_tree(ast.raw, SF))
        end
        SymbolTable.exit_main_module!()
    end
end

function parse(sf::SourceFile)
    return  try JS.parseall(SyntaxNode, JS.sourcetext(sf);
                            filename=sf.filename, ignore_trivia=false)
            catch xspt
                if xspt isa ParseError
                    foreach(dg->println(dg), xspt.diagnostics)
                else
                    println(xspt)
                end
                nothing
            end
end


function process(node::SyntaxNode)
    if is_eval_call(node) || kind(node) == K"quote"
        # There are corners we don't want to inspect.
        return nothing
    end

    if is_module(node)
        SymbolTable.enter_module!(node)
        Checks.SingleModuleFile.check(node)
        Checks.ModuleNameCasing.check(node)
        Checks.ModuleExportLocation.check(node)
        Checks.ModuleImportLocation.check(node)
        Checks.ModuleIncludeLocation.check(node)
        Checks.ModuleSingleImportLine.check(node)
    end

    if is_global_decl(node) process_global(node) end

    if is_loop(node) process_loop(node) end

    if is_function(node) process_function(node) end

    if is_struct(node) process_struct(node) end

    if is_abstract(node) process_type_declaration(node) end

    if is_operator(node) process_operator(node) end

    if is_union_decl(node) process_unions(node) end

    if is_literal_number(node) process_literal(node) end

    if is_flow_cntrl(node) process_flow_control(node) end

    if is_array_indx(node) Checks.UseEachindexToIterateIndices.check(node) end

    try for x in children(node) process(x) end
    catch xspt
        @error "Unexpected error while processing expression at $(JS.source_location(node)):" xspt
        # Stop processing this branch, but continue with the rest of the tree
    end

    # "Post-processing", before returning from this level of the tree
    if is_module(node) SymbolTable.exit_module!()
    elseif opens_scope(node) SymbolTable.exit_scope!()
    end
end

function process_operator(node::AnyTree)
    if JS.is_prefix_op_call(node)
        # something with prefix operators

    elseif is_infix_operator(node)
        #Checks.SpaceAroundInfixOperators.check(node)

        if is_assignment(node) process_assignment(node) end
        if is_eq_neq_comparison(node)
            if numchildren(node) != 3
                @debug "A comparison with a number of children != 3 at $(JS.source_location(node))" node
            else
                lhs, _, rhs = children(node)
                Checks.UseIsinfToCheckForInfinite.check.([lhs, rhs])
                Checks.UseIsnanToCheckForNan.check.([lhs, rhs])
                Checks.UseIsmissingToCheckForMissingValues.check.([lhs, rhs])
                Checks.UseIsnothingToCheckForNothingValues.check.([lhs, rhs])
            end
        end

    elseif JS.is_postfix_op_call(node)
        # something with postfix operators
    end

    # These type operators (<: >:) can appear not only as infix, but also as
    # prefix (or postfix?) operators
    if is_type_op(node) process_type_restriction(node) end
end

function process_function(node::SyntaxNode)
    fname = get_func_name(node)
    if isnothing(fname)
        # There is nothing left to check, except the debug logging output, where
        # we might see a clue of what we are dealing with.
        @debug "Can't find function name in a function node $(JS.source_location(node)):" node
        fname_str = "[anonymous]"
    else
        if kind(fname) == K"Identifier"
            Checks.FunctionIdentifiersInLowerSnakeCase.check(fname)
            SymbolTable.declare!(fname)
        #else
        # Otherwise, it might be an operator being redefined, which is certainly
        # not subject to casing inspection, nor we need to get it declared.
        end
        fname_str = string(fname)   # in either case, we take it as a string
    end
    SymbolTable.enter_scope!()
    for arg in get_func_arguments(node)
        if kind(arg) == K"parameters"
            if ! haschildren(arg)
                @debug "Odd case of childless [parameters] node $(JS.source_location(node)):" node
                return nothing
            end
            # The last argument in the list is itself a list, of named arguments.
            for arg in children(arg)
                process_argument(fname_str, arg)
            end
        else
            process_argument(fname_str, arg)
        end
    end

    body = get_func_body(node)
    if ! isnothing(body)
        Checks.LongFormFunctionsHaveATerminatingReturnStatement.check(body)
        Checks.ShortHandFunctionTooComplicated.check(body)
    end
end

function process_argument(fname::String, node::SyntaxNode)
    arg = find_lhs_of_kind(K"Identifier", node)
    if isnothing(arg)
        # Probably not a real argument, but a `::Val(Type)` to fix dispatch, or
        # something as tricky.
        return nothing
    end
    SymbolTable.declare!(arg)
    Checks.FunctionArgumentsInLowerSnakeCase.check(fname, arg)
end

function process_assignment(node::SyntaxNode)
    lhs = get_assignee(node)
    Checks.DoNotSetVariablesToInf.check(node)
    Checks.DoNotSetVariablesToNan.check(node)
    SymbolTable.declare!(first(lhs))
end
process_assignment(_::LosslessNode) = nothing

function process_literal(node::SyntaxNode)
    Checks.AvoidHardCodedNumbers.check(node)
    if     (kind(node) == K"Integer")
    elseif (kind(node) == K"Float")
        Checks.LeadingAndTrailingDigits.check(node)
    end
end

function process_struct(node::SyntaxNode)
    type_name = find_lhs_of_kind(K"Identifier", node)
    SymbolTable.declare!(type_name)
    Checks.TypeNamesUpperCamelCase.check(type_name)
    for field in get_struct_members(node)
        Checks.StructMembersAreInLowerSnakeCase.check(field)
    end
end

function process_type_declaration(node::SyntaxNode)
    Checks.PrefixOfAbstractTypeNames.check(node)
end

function process_type_restriction(_::SyntaxNode) return nothing end
function process_type_restriction(node::LosslessNode)
    Checks.NoWhitespaceAroundTypeOperators.check(node)
end

function process_unions(node::SyntaxNode)
    Checks.TooManyTypesInUnions.check(node)
    Checks.ImplementUnionsAsConsts.check(node)
end

function process_loop(node::SyntaxNode)
    if kind(node) == K"while" Checks.InfiniteWhileLoop.check(node) end
end

function process_global(node::SyntaxNode)
    id = find_lhs_of_kind(K"Identifier", node)
    if isnothing(id)
        @debug "No identifier found in a declaration $(JS.source_location(node)):" node
        return nothing
    end
    # Don't bother if already declared before, to prevent multiple reports
    if ! SymbolTable.is_global(id)
        SymbolTable.declare!(SymbolTable.global_scope(), id)
        Checks.AvoidGlobalVariables.check(id)
        Checks.GlobalVariablesUpperSnakeCase.check(id)
        Checks.LocationOfGlobalVariables.check(node)
        if is_constant(node)
            Checks.DocumentConstants.check(node)
        else
            Checks.GlobalNonConstVariablesShouldHaveTypeAnnotations.check(node)
            Checks.PreferConstVariablesOverNonConstGlobalVariables.check(id)
        end
    end
end

function process_flow_control(node::SyntaxNode)
    Checks.NestingOfConditionalStatements.check(node)
    if kind(node) == K"for"
        Checks.DoNotChangeGeneratedIndices.check(node)
    end
end

function process_with_trivia(node::LosslessNode)
    if is_leaf(node)
        if is_whitespace(node)
            Checks.UseSpacesInsteadOfTabs.check(node)
            Checks.IndentationLevelsAreFourSpaces.check(node)
            Checks.OmitTrailingWhiteSpace.check(node)

        elseif kind(node) == K"end"
            Checks.ModuleEndComment.check(node)

        elseif kind(node) == K"String"
            Checks.OmitTrailingWhiteSpace.check(node)

        elseif is_separator(node)
            # Checks.SingleSpaceAfterCommasAndSemicolons.check(node, parent)
        end
    else
        if is_eval_call(node) || kind(node) == K"quote"
            # There are corners we don't want to inspect.
            return nothing
        end
        if     is_toplevel(node) reset_counters()
        elseif is_operator(node) process_operator(node)
        end
        for x in children(node) process_with_trivia(x) end
    end
end


end
