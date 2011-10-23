-module(mockgyver_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-include("../include/mockgyver.hrl").

-compile(export_all).

%% was_called_test() ->
%%     mockgyver:start_link(),
%%     mockgyver:start_session([{x, test, 1}]),
%%     x:test(1),
%%     x:test(2),
%%     proc_lib:spawn(fun() -> x:test(2) end),
%% %    timer:sleep(100),
%%     ok = mockgyver:was_called({x, test, dbg:fun2ms(fun([1]) -> ok end)}, once),
%%     ok = mockgyver:was_called({x, test, dbg:fun2ms(fun([2]) -> ok end)}, {times, 2}),
%%     ok = mockgyver:was_called({x, test, dbg:fun2ms(fun([2]) -> ok end)}, {at_least, 2}),
%%     ok = mockgyver:was_called({x, test, dbg:fun2ms(fun([3]) -> ok end)}, never).

mock_test_() ->
    code:add_patha(filename:dirname(code:which(?MODULE))),
    Ts = [fun traces_single_arg/0,
          fun traces_multi_args/0,
          fun traces_in_separate_process/0,
          fun traces_in_separate_process/0,
          fun was_called_defaults_to_once/0,
          fun matches_called_arguments/0,
          fun allows_was_called_guards/0,
          fun allows_was_called_guards_with_variables_not_used_in_args_list/0,
          fun returns_called_arguments/0,
          fun allows_variables_in_criteria/0,
          fun returns_error_on_invalid_criteria/0,
          fun checks_that_two_different_functions_are_called/0,
          fun returns_immediately_if_waiters_criteria_already_fulfilled/0,
          fun waits_until_waiters_criteria_fulfilled/0,
          fun returns_other_value/0,
          fun can_change_return_value/0,
          fun inherits_variables_from_outer_scope/0,
          fun can_use_params/0,
          fun can_use_multi_clause_functions/0],
    [fun() -> ?MOCK(T) end || T <- Ts].

traces_single_arg() ->
    1 = mockgyver_dummy:return_arg(1),
    2 = mockgyver_dummy:return_arg(2),
    2 = mockgyver_dummy:return_arg(2),
    ?WAS_CALLED(mockgyver_dummy:return_arg(1), once),
    ?WAS_CALLED(mockgyver_dummy:return_arg(2), {times, 2}),
    ?WAS_CALLED(mockgyver_dummy:return_arg(_), {times, 3}).

traces_multi_args() ->
    {a, 1} = mockgyver_dummy:return_arg(a, 1),
    {a, 2} = mockgyver_dummy:return_arg(a, 2),
    {b, 2} = mockgyver_dummy:return_arg(b, 2),
    ?WAS_CALLED(mockgyver_dummy:return_arg(a, 1), once),
    ?WAS_CALLED(mockgyver_dummy:return_arg(a, 2), once),
    ?WAS_CALLED(mockgyver_dummy:return_arg(b, 2), once),
    ?WAS_CALLED(mockgyver_dummy:return_arg(_, 1), {times, 1}),
    ?WAS_CALLED(mockgyver_dummy:return_arg(_, 2), {times, 2}).

traces_in_separate_process() ->
    Pid = proc_lib:spawn_link(fun() -> mockgyver_dummy:return_arg(1) end),
    MRef = erlang:monitor(process, Pid),
    receive {'DOWN',MRef,_,_,_} -> ok end,
    ?WAS_CALLED(mockgyver_dummy:return_arg(_), once).

was_called_defaults_to_once() ->
    mockgyver_dummy:return_arg(1),
    ?WAS_CALLED(mockgyver_dummy:return_arg(_)),
    mockgyver_dummy:return_arg(1),
    ?assertError(_, ?WAS_CALLED(mockgyver_dummy:return_arg(_))).

matches_called_arguments() ->
    N = 42,
    O = 1,
    mockgyver_dummy:return_arg(1),
    mockgyver_dummy:return_arg({N,O}),
    ?WAS_CALLED(mockgyver_dummy:return_arg(N), never),
    ?WAS_CALLED(mockgyver_dummy:return_arg(O), once),
    ?WAS_CALLED(mockgyver_dummy:return_arg({_,N}), never),
    ?WAS_CALLED(mockgyver_dummy:return_arg({N,O}), once).

allows_was_called_guards() ->
    mockgyver_dummy:return_arg(1),
    ?WAS_CALLED(mockgyver_dummy:return_arg(N) when N == 1, once),
    ?WAS_CALLED(mockgyver_dummy:return_arg(N) when N == 2, never).

allows_was_called_guards_with_variables_not_used_in_args_list() ->
    W = 2,
    mockgyver_dummy:return_arg(1),
    ?WAS_CALLED(mockgyver_dummy:return_arg(_) when W == 2, once).

returns_called_arguments() ->
    mockgyver_dummy:return_arg(1),
    mockgyver_dummy:return_arg(2),
    [[1], [2]] = ?WAS_CALLED(mockgyver_dummy:return_arg(N), {times, 2}).

allows_variables_in_criteria() ->
    C = {times, 0},
    ?WAS_CALLED(mockgyver_dummy:return_arg(_), C).

returns_error_on_invalid_criteria() ->
    lists:foreach(
      fun(C) ->
              ?assertError({invalid_criteria, C},
                           ?WAS_CALLED(mockgyver_dummy:return_arg(_), C))
      end,
      [0,
       x,
       {at_least, x},
       {at_most, x},
       {times, x}]).

checks_that_two_different_functions_are_called() ->
    mockgyver_dummy:return_arg(1),
    mockgyver_dummy:return_arg2(1),
    ?WAS_CALLED(mockgyver_dummy:return_arg(1), once),
    ?WAS_CALLED(mockgyver_dummy:return_arg2(1), once).

returns_immediately_if_waiters_criteria_already_fulfilled() ->
    mockgyver_dummy:return_arg(1),
    ?WAIT_CALLED(mockgyver_dummy:return_arg(N), once).

waits_until_waiters_criteria_fulfilled() ->
    spawn(fun() -> timer:sleep(50), mockgyver_dummy:return_arg(1) end),
    ?WAIT_CALLED(mockgyver_dummy:return_arg(N), once).

returns_other_value() ->
    1  = mockgyver_dummy:return_arg(1),
    2  = mockgyver_dummy:return_arg(2),
    ?WHEN(mockgyver_dummy:return_arg(1) -> 42),
    42 = mockgyver_dummy:return_arg(1),
    ?assertError(function_clause, mockgyver_dummy:return_arg(2)).

can_change_return_value() ->
    1  = mockgyver_dummy:return_arg(1),
    ?WHEN(mockgyver_dummy:return_arg(1) -> 42),
    42 = mockgyver_dummy:return_arg(1),
    ?assertError(function_clause, mockgyver_dummy:return_arg(2)),
    ?WHEN(mockgyver_dummy:return_arg(_) -> 43),
    43 = mockgyver_dummy:return_arg(1),
    43 = mockgyver_dummy:return_arg(2).

inherits_variables_from_outer_scope() ->
    NewVal = 42,
    ?WHEN(mockgyver_dummy:return_arg(_) -> NewVal),
    42 = mockgyver_dummy:return_arg(1).

can_use_params() ->
    ?WHEN(mockgyver_dummy:return_arg(N) -> N+1),
    2 = mockgyver_dummy:return_arg(1).

can_use_multi_clause_functions() ->
    ?WHEN(mockgyver_dummy:return_arg(N) when N >= 0 -> positive;
          mockgyver_dummy:return_arg(_N)            -> negative),
    positive = mockgyver_dummy:return_arg(1),
    negative = mockgyver_dummy:return_arg(-1).
