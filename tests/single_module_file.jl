module single_module_file

module SubModuleIsOK
end

end     # module single_module_file

module SecondModuleNotOK
end

function out_of_module_is_wrong()
    return nothing
end

module ThirdInFile
end
