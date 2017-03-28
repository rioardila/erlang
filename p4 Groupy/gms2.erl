-module(gms2).
-export([start/1, start/2]).

start(Name) ->
    Self = self(),
    spawn_link(fun()-> init(Name, Self) end).

init(Name, Master) ->
    {A1,A2,A3} = now(),
    random:seed(A1,A2,A3),
    leader(Name, Master, []).

start(Name, Grp) ->
    Self = self(),
    spawn_link(fun()-> init(Name, Grp, Self) end).    

init(Name, Grp, Master) ->
    Self = self(),
    {A1,A2,A3} = now(),
    random:seed(A1,A2,A3), 
    Grp ! {join, Self},
    receive
        {view, Leader, Slaves} ->
            Master ! joined,
            Ref = erlang:monitor(process, Leader), %%NEW!!!
            slave(Name, Master, Leader, Slaves, Ref)
    after 1000 -> %%NEW!!!
        Master ! {error, "no reply from leader"} %%NEW!!!
    end.

leader(Name, Master, Slaves) ->    
    receive
        {mcast, Msg} ->
            bcast(Name, {msg, Msg}, Slaves),  %% TODO: COMPLETE
            %% TODO: ADD SOME CODE
	    Master ! {deliver, Msg},
            leader(Name, Master, Slaves);
        {join, Peer} ->
            NewSlaves = lists:append(Slaves, [Peer]),           
            bcast(Name, {view, self(), NewSlaves}, NewSlaves),  %% TODO: COMPLETE
            leader(Name, Master, NewSlaves);  %% TODO: COMPLETE
        stop ->
            ok;
        Error ->
            io:format("leader ~s: strange message ~w~n", [Name, Error])
    end.
    
bcast(Name, Msg, Nodes) ->
    lists:foreach(fun(Node) ->
        Node ! Msg,
        crash(Name, Msg)
        end,
        Nodes).

crash(Name, Msg) ->
    case random:uniform(100) of
         100 ->
             io:format("leader ~s CRASHED: msg ~w~n", [Name, Msg]),
             exit(no_luck);
         _ ->
             ok
    end.

slave(Name, Master, Leader, Slaves, Ref) ->    
    receive
        {mcast, Msg} ->
            %% TODO: ADD SOME CODE
	    Leader ! {mcast, Msg}, %%??
            slave(Name, Master, Leader, Slaves, Ref);
        {join, Peer} ->
            %% TODO: ADD SOME CODE
	    Leader ! {join, Peer}, %%??
            slave(Name, Master, Leader, Slaves, Ref);
        {msg, Msg} ->
            %% TODO: ADD SOME CODE
	    Master ! {deliver, Msg}, %%??
            slave(Name, Master, Leader, Slaves, Ref);
        {view, NewLeader, NewSlaves} ->
            erlang:demonitor(Ref, [flush]),
            NewRef = erlang:monitor(process, NewLeader),
            slave(Name, Master, NewLeader, NewSlaves, NewRef);  %% TODO: COMPLETE
        {'DOWN', _Ref, process, Leader, _Reason} -> %%NEW!!!
            election(Name, Master, Slaves); %%NEW!!!
        stop ->
            ok;
        Error ->
            io:format("slave ~s: strange message ~w~n", [Name, Error])
    end.

election(Name, Master, Slaves) ->
    Self = self(),
    case Slaves of
        [Self|Rest] ->
            %%TODO: ADD SOME CODE HERE     
            bcast(Name, {view, Self, Rest}, Rest),
            leader(Name, Master, Rest);  %%TODO: COMPLETE
        [NewLeader|Rest] ->
            %% TODO: ADD SOME CODE HERE
 	    NewRef = erlang:monitor(process, NewLeader), %%NEW!!!
            slave(Name, Master, NewLeader, Rest, NewRef) %%TODO: COMPLETE
    end.






