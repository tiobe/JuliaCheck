module Process

import JuliaSyntax: GreenNode, SyntaxNode, SourceFile, ParseError, @K_str,
    children, is_whitespace, kind, numchildren, span, untokenize,
    JuliaSyntax as JS

using ..Properties
import ..Checks
include("SymbolTable.jl"); import .SymbolTable

export check


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
        end
        process(ast)
        #if trivia_checks_enabled
            process_with_trivia(ast.raw, ast.raw)
        #end
        SymbolTable.exit_module!()   # leave `Main`
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
    if haschildren(node)
        if is_toplevel(node)
            SymbolTable.enter_main_module!()
        end
        if is_module(node)
            SymbolTable.enter_module!(node)
            Checks.SingleModuleFile.check(node)
            Checks.ModuleNameCasing.check(node)
            Checks.ModuleEndComment.check(node)
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

        for x in children(node) process(x) end
    else
        if is_literal(node) process_literal(node) end
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
                @debug "A comparison with a number of children != 3" node
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
        @debug "Can't find function name" node
        return nothing
    end
    Checks.FunctionIdentifiersInLowerSnakeCase.check(fname)
    SymbolTable.declare!(fname)
    SymbolTable.enter_scope!()
    for arg in get_func_arguments(node)
        if kind(arg) == K"parameters"
            if ! haschildren(arg)
                @debug "Odd case of childless [parameters] node" arg
                return nothing
            end
            # The last argument in the list is itself a list, of named arguments.
            for arg in children(arg)
                if kind(arg) == K"=" arg = first(get_assignee(arg)) end
                process_argument(fname, arg)
            end
        else
            process_argument(fname, arg)
        end
    end

    body = get_func_body(node)
    if ! isnothing(body)
        Checks.LongFormFunctionsHaveATerminatingReturnStatement.check(body)
        Checks.ShortHandFunctionTooComplicated.check(body)
    end
end

function process_argument(fname::SyntaxNode, node::SyntaxNode)
    if kind(node) == K"::"
        if numchildren(node) == 2
            arg = children(node)[1]
        else
            # Probably not a real argument, but a `::Val(Type)` to fix dispatch,
            # or maybe some other kind of weird thing.
            return nothing
        end
    else
        arg = node
    end
    SymbolTable.declare!(arg)
    Checks.FunctionArgumentsInLowerSnakeCase.check(fname, arg)
end

function process_assignment(node::SyntaxNode)
    lhs = get_assignee(node)
    Checks.DoNotSetVariablesToInf.check(node)
    Checks.DoNotSetVariablesToNan.check(node)
    SymbolTable.declare!(first(lhs))
    # Checks.AvoidGlobals.check(node)
end
process_assignment(_::GreenNode) = nothing

function process_literal(node::SyntaxNode)
    if     (kind(node) == K"Integer")
    elseif (kind(node) == K"Float")
        Checks.LeadingAndTrailingDigits.check(node)
    end
end

function process_struct(node::SyntaxNode)
    type_name = find_first_of_kind(K"Identifier", node)
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
function process_type_restriction(node::GreenNode)
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
    id = find_first_of_kind(K"Identifier", node)
    if isnothing(id)
        @debug "No identifier found in a declaration" node
    end
    # Don't bother if already declared before, to prevent multiple reports
    if ! SymbolTable.is_global(id)
        SymbolTable.declare!(SymbolTable.global_scope(), id)
        Checks.AvoidGlobalVariables.check(id)
        if is_constant(node)
            Checks.DocumentConstants.check(node)
        end
    end
end


function process_with_trivia(node::GreenNode, parent::GreenNode)
    if haschildren(node)
        if     is_toplevel(node) reset_counters()
        elseif is_operator(node) process_operator(node)
        end
        for x in children(node) process_with_trivia(x, node) end
    else
        if is_whitespace(node)
            Checks.UseSpacesInsteadOfTabs.check(node)
            Checks.IndentationLevelsAreFourSpaces.check(node)
            Checks.OmitTrailingWhiteSpace.check(node)

        elseif kind(node) == K"String"
            Checks.OmitTrailingWhiteSpace.check(node)

        elseif is_separator(node)
            Checks.SingleSpaceAfterCommasAndSemicolons.check(node, parent)
        end
        increase_counters(node)
    end
end


end
