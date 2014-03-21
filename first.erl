%% @author UserX
%% @doc @todo Add description to first.


-module(first).

%% ====================================================================
%% API functions
%% ====================================================================
-export([hello_world/0, start/1, getTheColor/0, setTheColor/1, color/1]).

hello_world() -> io:fwrite("hello, you smelly world\n").

start(Port) ->
    spawn(fun () -> {ok, Sock} = gen_tcp:listen(Port, [{active, false}]),

    loop(Sock) 
	end),
	register(myColor, spawn(firstModule, color, ["blue"])),
	getTheColor().

getTheColor()->
	%check to make sure myColor is still alive and registered. if not awake it.
	PidOfMyColor = whereis(myColor),
	case PidOfMyColor =/= undefined of
		 true ->
		   myColor ! {getColor, self()},
		   receive
			   {colorRequest, TheColor} -> 
				   io:fwrite(string:concat("received the color request ",TheColor)),
				   io:fwrite("\n")
		   end;
	    false -> 
			TheColor = "blue",
			io:fwrite("Color process had died, we restarted it with default value of: " ++ TheColor),
			register(myColor, spawn(firstModule, color, [TheColor]))
	end,
	TheColor.

setTheColor(NewColor)->
	myColor ! {changeColor, NewColor}.


%% ====================================================================
%% Internal functions
%% ====================================================================

loop(Sock) ->
    {ok, Conn} = gen_tcp:accept(Sock),
	TheColor = getTheColor(),
	Handler = spawn(fun () -> handle(Conn,TheColor) end),
    gen_tcp:controlling_process(Conn, Handler),
    loop(Sock).

handle(Conn, Num) ->
	io:fwrite("in the handle method \n"),
	{ok, Packet} = gen_tcp:recv(Conn, 0, 5000),
    gen_tcp:send(Conn, response("Yo Baby its gravy " ++ Num ++ " <br/><br/><br/> "++ Packet)),
    gen_tcp:close(Conn).


color(OldColor) ->
	receive
		finished ->
			io:fwrite("Color holder finished");
		{changeColor, NewColor} ->
			io:fwrite(string:concat("changed color to ", NewColor)),
			color(NewColor);
		{getColor, Pid} -> 
			Pid ! {colorRequest, OldColor},
			color(OldColor)
	end.

response(Str) ->
    B = iolist_to_binary(Str),
    iolist_to_binary(
      io_lib:fwrite(
         "HTTP/1.0 200 OK\nContent-Type: text/html\nContent-Length: ~p\n\n~s",
         [size(B), B])).


