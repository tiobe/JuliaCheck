# get data from query item
function get_data!(lote_inventory, item)
    """
    input item structure:
        item[Key_GofreId] = gofre id
       item[Key_QueryData] = "nominal position"

   output item structure:
        result[Key_UUID] = item[Key_UUID]
        result[Key_LoteId] = item[Key_LoteId]
        result[Key_GofreId] = item[Key_GofreId]
        result[Key_Query] = item[Key_Query]
        result[Key_QueryData] = item[Key_QueryData]
        result[Key_QueryResult] = quest result data
    """
    result = Dict()
    result[Key_UUID] = item[Key_UUID]
    result[Key_LoteId] = item[Key_LoteId]
    result[Key_GofreId] = item[Key_GofreId]
    result[Key_Query] = item[Key_Query]
    result[Key_QueryData] = item[Key_QueryData]

    request = AlignmentAnalyzer.RetrieveData.Request(
                                                gofreId = item[Key_GofreId],
                                                processName = item[Key_Query],
                                               # ruleid: indentation-levels-are-four-spaces
                                                 dataSpec = item[Key_QueryData],
                                                saveCalc = true)

    result[Key_QueryStatus], result[Key_QueryResult] =
        # ruleid: indentation-levels-are-four-spaces
          AlignmentAnalyzer.RetrieveData.retrieveDataFrame!(lote_inventory, request)
    return result
# ruleid: indentation-levels-are-four-spaces
 end

#=
     input item structure:
        item[Key_GofreId] = gofre id
       item[Key_QueryData] = "nominal position"

   output item structure:
        result[Key_UUID] = item[Key_UUID]
        result[Key_LoteId] = item[Key_LoteId]
        result[Key_GofreId] = item[Key_GofreId]
        result[Key_Query] = item[Key_Query]
        result[Key_QueryData] = item[Key_QueryData]
        result[Key_QueryResult] = quest result data
=#
