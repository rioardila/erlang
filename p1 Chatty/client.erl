-module(client).
%% Exported Functions
-export([start/2]).

%% API Functions
start(ServerPid, MyName) ->
    ClientPid = spawn(fun() -> init_client(ServerPid, MyName) end),
    process_commands(ServerPid, MyName, ClientPid).

init_client(ServerPid, MyName) ->
    ServerPid ! {client_join_req, MyName, self()},  %% TODO: COMPLETE
    process_requests().

%% Local Functions
%% This is the background task logic
process_requests() ->
    receive
        {join, Name} ->
            io:format("[JOIN] ~s joined the chat~n", [Name]),
            %% TODO: ADD SOME CODE
            process_requests();
        {leave, Name} ->
            %% TODO: ADD SOME CODE
            io:format("[JOIN] ~s left the chat~n", [Name]),
            process_requests();
        {message, Name, Text} ->
            io:format("[~s] ~s", [Name, Text]),
            %% TODO: ADD SOME CODE
	    process_requests();	
        exit -> 
            ok
    end.

%% This is the main task logic
process_commands(ServerPid, MyName, ClientPid) ->
    %% Read from standard input and send to server
    Text = io:get_line("-> "),
    if 
        Text  == "exit\n" ->
            ServerPid ! {client_leave_req, MyName, ClientPid},  %% TODO: COMPLETE
            ok;
        true ->
            ServerPid ! {send, MyName, Text},  %% TODO: COMPLETE
            process_commands(ServerPid, MyName, ClientPid)
    end.