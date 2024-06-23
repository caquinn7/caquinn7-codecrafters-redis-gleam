-module(ets_utils_ffi).
-export([get_all_keys/1]).

get_all_keys(Table) ->
    Keys = ets:match(Table, {'$1', '_'}),
    lists:flatten(Keys).