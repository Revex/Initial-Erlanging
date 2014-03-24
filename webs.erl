
%% @doc this module starts up a very basic web server, and allows a value change.  
%% @doc it's purpose is a proof of concept for interacting with GPIO pins on a raspberry pi remotely.

-module(webs).

%% ====================================================================
%% API functions
%% ====================================================================
-export([start/0, start/1, getTheColor/0, setTheColor/1, color/1]).

start()->
    start("bah").

start(Nothing) ->
    Port = 80,
    spawn(fun () -> {ok, Sock} = gen_tcp:listen(Port, [{active, false}]),

    loop(Sock) 
	end),
	register(myColor, spawn(webs, color, ["blue"])),
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
			register(myColor, spawn(webs, color, [TheColor]))
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
    
    %we must parse the Packet (it is an HTTP request)
    %first lets find out if it is a Get or a Put (we don't care about any other ones)
    
    HttpMethod = string:substr(Packet, 1, 4),   
    if 
	HttpMethod =:= "GET " ->
	    gen_tcp:send(Conn, response("Yo Baby its gravy, and the values is: <h2>" ++ Num ++ "</h2><br /><br /><br />
<form method='POST'> 
Entry: <input type='text' name='MyEntry' /> 
<input type='submit' />
</form>

 "));
	HttpMethod =:= "PUT " ->
	    PositionBeforeHttp = string:str(Packet, " HTTP/1") - string:len(" HTTP/1") + 2,
	    Request = string:substr(Packet, 5, PositionBeforeHttp),
	    first:setTheColor(string:substr(Request,2)),
	    gen_tcp:send(Conn, response("Yeah we set it, up for ya"));
	HttpMethod =:= "POST" ->
	    Request = string:substr(Packet, 6),
		Property = "MyEntry=",
		io:fwrite("I'm in the post method handler\n"),
		PositionOfMyEntry = string:rstr(Request, Property),
		LengthOfMyEntry = string:len(Property),
		io:fwrite("This is the positionfoMyEntry: "++erlang:integer_to_list(PositionOfMyEntry)),
		MyEntry = string:substr(Request, PositionOfMyEntry + LengthOfMyEntry),
	    io:fwrite(MyEntry),
	    gen_tcp:send(Conn, response("We see you posted  this: <br/>"
								   ++MyEntry 
								   ++ "<br /><br /><h2>So we changed the value to "
								   ++MyEntry
								   ++"!!</h2><br /><br /><br /><br /> <a href='/'>Click to Check and See</a>"
								   ++"<br/><br/><br/>"
								   ++Packet)),
		webs:setTheColor(MyEntry)
	   
%TODO if a HttpMethod is not get or put it will cause an error, fix that
   end,
    
    gen_tcp:close(Conn),
    Packet.


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


