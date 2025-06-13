module Process

import JuliaSyntax: GreenNode, SyntaxNode, SourceFile, ParseError, @K_str,
    children, is_whitespace, kind, numchildren, span, untokenize,
    JuliaSyntax as JS

# include("SymbolTable.jl")
# import .SymbolTable

include("Properties.jl")
using .Properties

include("Checks.jl")
import .Checks

export check


function check(file_name::String)
    Properties.SF = SourceFile(; filename=file_name)
    ast = parse(SF)
    if isnothing(ast)
        @error "Couldn't parse file '$file_name'"
    else
        @debug "Full AST for the file:" ast
        # @debug "\n" * sprint(show, MIME"text/plain"(), ast.raw, string(JS.sourcetext(SF)))
        # TODO Perhaps, printing the GreenNode tree should be an explicit separate option.
        process(ast)
        #if trivia_checks_enabled
            process_with_trivia(ast.raw, ast.raw)
        #end
        #SymbolTable.exit_module()   # leave `Main`
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
            #SymbolTable.enter_module()  # There is always the `Main` module
            # TODO: a file can be `include`d into another, thus into another
            # module and, what is most important from the point of view of the
            # symbols table and declarations: something can be declared outside
            # the file under analysis, and we will surely get confused about its
            # scope.

        elseif is_module(node)
            #SymbolTable.enter_module(node)
            Checks.SingleModuleFile.check(node)
            Checks.ModuleNameCasing.check(node)
            Checks.ModuleEndComment.check(node)
            Checks.ModuleExportLocation.check(node)
            Checks.ModuleImportLocation.check(node)
            Checks.ModuleIncludeLocation.check(node)
            Checks.ModuleSingleImportLine.check(node)

        elseif is_operator(node)
            process_operator(node)

        elseif is_loop(node)
            process_loop(node)

        elseif is_function(node)
            process_function(node)

        elseif is_struct(node)
            process_struct(node)

        elseif is_abstract(node)
            process_type_declaration(node)

        elseif is_constant(node)
            Checks.DocumentConstants.check(node)

        elseif is_union_decl(node)
            process_unions(node)

        end
        for x in children(node) process(x) end
    else
        # FIXME: [end] nodes belong in GreenNode trees only! Thus, the following
        # functions 'closes_module' and 'closes_scope' are useless!
        if closes_module(node)
            #SymbolTable.exit_module(node.parent)
        elseif closes_scope(node)
            #SymbolTable.exit_scope()
        elseif is_literal(node)
            process_literal(node)
        end
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

    # Two of these type operators (<: >:) can appear not only as infix, but also
    # as prefix or postfix operators
    if is_type_op(node) process_type_restriction(node) end
end

function process_function(node::SyntaxNode)
    fname = get_func_name(node)
    if isnothing(fname)
        # There is nothing left to check, except the debug logging output, where
        # we might see a clue of what we are dealing with.
        return nothing
    end
    Checks.FunctionIdentifiersCasing.check(fname)
    #SymbolTable.declare(fname)
    #SymbolTable.enter_scope()
    named_arguments = []
    for arg in get_func_arguments(node)
        if kind(arg) == K"parameters" && haschildren(arg)
            # The last argument in the list is itself a list, of named arguments,
            # which we are going to process next.
            named_arguments = children(arg)
        else
            # SymbolTable.declare(arg)
            Checks.FunctionArgumentsCasing.check(fname, arg)
        end
    end
    for arg in named_arguments
        Checks.FunctionArgumentsCasing.check(fname, arg)
    end

    body = get_func_body(node)
    if ! isnothing(body)
        Checks.LongFormFunctionsHaveReturnStatement.check(body)
        Checks.ShortHandFunctionTooComplicated.check(body)
    end
end

function process_assignment(node::SyntaxNode)
    lhs = get_assignee(node)
    Checks.DoNotSetVariablesToInf.check(node)
    Checks.DoNotSetVariablesToNan.check(node)
    # if !SymbolTable.is_declared(lhs)
    #     SymbolTable.declare(lhs)
    # end
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
    Checks.TypeNamesCasing.check(node)
    for field in get_struct_members(node)
        Checks.StructMembersCasing.check(field)
    end
end

function process_type_declaration(node::SyntaxNode)
    Checks.AbstractTypeNames.check(node)
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
        end
        increase_counters(node)
    end
end


end
