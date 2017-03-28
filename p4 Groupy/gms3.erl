-module(gms3).
-export([start/1, start/2]).

start(Name) ->
    Self = self(),
    spawn_link(fun()-> init(Name, Self) end).

init(Name, Master) ->
    {A1,A2,A3} = now(),
    random:seed(A1,A2,A3),
    leader(Name, Master, [], 0).

start(Name, Grp) ->
    Self = self(),
    spawn_link(fun()-> init(Name, Grp, Self) end).    

init(Name, Grp, Master) ->
    Self = self(),
    {A1,A2,A3} = now(),
    random:seed(A1,A2,A3), 
    Grp ! {join, Self},
    receive
        {view, Leader, Slaves, Id} ->
            Master ! joined,
            Ref = erlang:monitor(process, Leader), %%NEW!!!
            slave(Name, Master, Leader, Slaves, Ref, Id, '' )
    after 1000 -> %%NEW!!!
        Master ! {error, "no reply from leader"} %%NEW!!!
    end.

leader(Name, Master, Slaves, N) ->    
    receive
        {mcast, Msg} ->
            bcast(Name, {msg, Msg, N+1}, Slaves),  %% TODO: COMPLETE
            %% TODO: ADD SOME CODE
	    Master ! {deliver, Msg},
            leader(Name, Master, Slaves, N+1);
        {join, Peer} ->
            NewSlaves = lists:append(Slaves, [Peer]),           
            bcast(Name, {view, self(), NewSlaves, N+1}, NewSlaves),  %% TODO: COMPLETE
            leader(Name, Master, NewSlaves, N+1);  %% TODO: COMPLETE
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
    case random:uniform(200) of
         200 ->
             io:format("leader ~s CRASHED: msg ~w~n", [Name, Msg]),
             exit(no_luck);
         _ ->
             ok
    end.

slave(Name, Master, Leader, Slaves, Ref, N, Last) ->    
    receive
        {mcast, Msg} ->
            %% TODO: ADD SOME CODE
	    Leader ! {mcast, Msg}, %%??
            slave(Name, Master, Leader, Slaves, Ref, N, Last);
        {join, Peer} ->
            %% TODO: ADD SOME CODE
	    Leader ! {join, Peer}, %%??
            slave(Name, Master, Leader, Slaves, Ref, N, Last);
        {msg, Msg, Id} ->
            %% TODO: ADD SOME CODE
            if Id > N ->
	           Master ! {deliver, Msg}, %%??
               slave(Name, Master, Leader, Slaves, Ref, Id, Msg);
            true ->
                 slave(Name, Master, Leader, Slaves, Ref, Id, Msg)
            end;
        {view, NewLeader, NewSlaves, Id} ->
             if Id > N -> 
                erlang:demonitor(Ref, [flush]),
                NewRef = erlang:monitor(process, NewLeader),
                slave(Name, Master, NewLeader, NewSlaves, NewRef, Id, Last);  %% TODO: COMPLETE
            true ->
                slave(Name, Master, NewLeader, NewSlaves, Ref, Id, Last)
            end;    
        {'DOWN', _Ref, process, Leader, _Reason} -> %%NEW!!!
            election(Name, Master, Slaves, N, Last); %%NEW!!!
        stop ->
            ok;
        Error ->
            io:format("slave ~s: strange messageshit ~w~n ", [Name, Error])
    end.

election(Name, Master, Slaves, N, Last) ->
    Self = self(),
    case Slaves of
        [Self|Rest] ->
            %%TODO: ADD SOME CODE HERE
            bcast(Name, {msg, Last, N}, Rest),    
            bcast(Name, {view, Self, Rest, N+1}, Rest),
            leader(Name, Master, Rest, N+1);  %%TODO: COMPLETE
        [NewLeader|Rest] ->
            %% TODO: ADD SOME CODE HERE
 	    NewRef = erlang:monitor(process, NewLeader), %%NEW!!!
            slave(Name, Master, NewLeader, Rest, NewRef, N, Last) %%TODO: COMPLETE
    end.






