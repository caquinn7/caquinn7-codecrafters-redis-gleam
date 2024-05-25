-module(binary_utils_ffi).
-export([safe_binary_to_integer/1]).

safe_binary_to_integer(Bin) ->
    try
        Result = binary_to_integer(Bin),
        {ok, Result}
    catch
        error:badarg ->
            {error, nil}
    end.