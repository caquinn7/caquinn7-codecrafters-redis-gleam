-module(binary_utils_ffi).
-export([
    safe_binary_to_integer/1,
    safe_decode_unsigned/1,
    safe_decode_unsigned_little/1
]).

safe_binary_to_integer(Bin) ->
    try
        Result = binary_to_integer(Bin),
        {ok, Result}
    catch
        error:badarg ->
            {error, nil}
    end.

safe_decode_unsigned(Subject) ->
    try
        Result = binary:decode_unsigned(Subject, big),
        {ok, Result}
    catch
        error:badarg ->
            {error, nil}
    end.

safe_decode_unsigned_little(Subject) ->
    try
        Result = binary:decode_unsigned(Subject, little),
        {ok, Result}
    catch
        error:badarg ->
            {error, nil}
    end.