-module(total).
-export([start/3]).

start(Id, Master, Jitter) ->
    spawn(fun() -> init(Id, Master, Jitter) end).

init(Id, Master, Jitter) ->
    {A1,A2,A3} = now(),
    random:seed(A1, A2, A3),
    receive
        {peers, Nodes} ->
            server(Master, seq:new(Id), seq:new(Id), Nodes, [], [], Jitter)
    end.

server(Master, MaxPrp, MaxAgr, Nodes, Cast, Queue, Jitter) ->
receive
    {send, Msg} ->
        Ref = make_ref(),
        request(Ref,Msg ,Nodes, Jitter),   %%TODO
        NewCast = cast(Ref, Nodes, Cast),	%%TODO
        server(Master, MaxPrp, MaxAgr, Nodes, NewCast, Queue, Jitter); %%TODO
    {request, From, Ref, Msg} ->
        NewMaxPrp = seq:increment(seq:maxfirst(MaxPrp,MaxAgr)) , %%TODO
        From ! {proposal, Ref, NewMaxPrp},%%TODO
        NewQueue = insert(Ref, Msg, NewMaxPrp, Queue),%%TODO
        server(Master, NewMaxPrp, MaxAgr, Nodes, Cast, NewQueue, Jitter);%%TODO
    {proposal, Ref, Proposal} ->
        case proposal(Ref, Proposal , Cast) of %%TODO Cast?
            {agreed, MaxSeq, NewCast} ->
                agree(Ref, MaxSeq, Nodes), %%TODO MaxSeq??
                server(Master, MaxPrp, MaxSeq, Nodes, NewCast, Queue, Jitter);%%TODO NewCast??? other??
            NewCast ->
                server(Master, MaxPrp, MaxAgr, Nodes, NewCast, Queue, Jitter) %%TODO New Cast??? other??
        end;
    {agreed, Ref, Seq} ->
        Updated = update(Ref , Seq , Queue),%%TODO Queue?
        {Agreed, NewQueue} = agreed(Updated),%%TODO
        deliver(Master , Agreed),%%TODO NweQueue??
        NewMaxAgr = seq:max(MaxAgr,Seq) ,%%TODO ??
        server(Master, MaxPrp, NewMaxAgr, Nodes, Cast, NewQueue, Jitter);%%TODO
    stop ->
        ok
end.

%% Sending a request message to all nodes
request(Ref, Msg, Nodes, 0) ->
    Self = self(),
    lists:foreach(fun(Node) -> 
                  Node ! {request, Self, Ref, Msg}    %% TODO: ADD SOME CODE
                  end, 
                  Nodes);
request(Ref, Msg, Nodes, Jitter) ->
    Self = self(),
    lists:foreach(fun(Node) ->
                      T = random:uniform(Jitter),
                      timer:send_after(T, Node, {request, Self, Ref, Msg} ) %% TODO: COMPLETE
                  end,
                  Nodes).
        
%% Sending an agreed message to all nodes
agree(Ref, Seq, Nodes)->
    lists:foreach(fun(Pid)-> 
                  Pid ! {agreed, Ref, Seq}    %% TODO: ADD SOME CODE
                  end, 
                  Nodes).

%% Delivering messages to the master
deliver(Master, Messages) ->
    lists:foreach(fun(Msg)-> 
                      Master ! {deliver, Msg} 
                  end, 
                  Messages).
                  
%% Adding a new entry to the set of casted messages
cast(Ref, Nodes, Cast) ->
    L = length(Nodes),
    [{Ref, L, seq:null()}|Cast].

%% Update the set of casted messages
proposal(Ref, Proposal, [{Ref, 1, Sofar}|Rest])->
    {agreed, seq:max(Proposal, Sofar), Rest};
proposal(Ref, Proposal, [{Ref, N, Sofar}|Rest])->
    [{Ref, N-1, seq:max(Proposal, Sofar)}|Rest];
proposal(Ref, Proposal, [Entry|Rest])->
    case proposal(Ref, Proposal, Rest) of
        {agreed, Agreed, Rst} ->
            {agreed, Agreed, [Entry|Rst]};
        Updated ->
            [Entry|Updated]
    end.
    
%% Remove all messages in the front of the queue that have been agreed
agreed([{_Ref, Msg, agrd, _Agr}|Queue]) ->
    {Agreed, Rest} = agreed(Queue),
    {[Msg|Agreed], Rest};
agreed(Queue) ->
    {[], Queue}.
    
%% Update the queue with an agreed sequence number
update(Ref, Agreed, [{Ref, Msg, propsd, _}|Rest])->
    queue(Ref, Msg, agrd, Agreed, Rest);
update(Ref, Agreed, [Entry|Rest])->
    [Entry|update(Ref, Agreed, Rest)].
    
%% Insert a new message into the queue
insert(Ref, Msg, Proposal, Queue) ->
    queue(Ref, Msg, propsd, Proposal, Queue).
    
%% Queue a new entry
queue(Ref, Msg, State, Proposal, []) ->
    [{Ref, Msg, State, Proposal}];
queue(Ref, Msg, State, Proposal, Queue) ->
    [Entry|Rest] = Queue,
    {_, _, _, Next} = Entry,
    case seq:lessthan(Proposal, Next) of
        true ->
            [{Ref, Msg, State, Proposal}|Queue];
        false ->
            [Entry|queue(Ref, Msg, State, Proposal, Rest)]
    end.
