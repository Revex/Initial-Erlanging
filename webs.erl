
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
    spawn(fun () -> {ok, Sock} = gen_tcp:listen(Port, [{active, false}]),loop(Sock) end),
    getTheColor(),
    io:fwrite("The web server has started ~n", []).

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
		registerMyColor(TheColor)
			end,
	TheColor.

setTheColor(NewColor)->
	myColor ! {changeColor, NewColor}.


%% ====================================================================
%% Internal functions
%% ====================================================================

registerMyColor(TheColor)->
    MyColorPid = whereis(myColor),
    case MyColorPid =:= undefined of
	true -> register(myColor, spawn(webs, color, [TheColor]));
	false  -> io:fwrite("myColor is still alive.")
    end.


getLedPid()->
    self().

loop(Sock) ->
    {ok, Conn} = gen_tcp:accept(Sock),
    Handler = spawn(fun () -> handle(Conn) end),
    gen_tcp:controlling_process(Conn, Handler),
    loop(Sock).

handle(Conn) ->
    io:fwrite("in the handle method \n"),
    {ok, Packet} = gen_tcp:recv(Conn, 0, 5000),
    
    %we must parse the Packet (it is an HTTP request)
    %first lets find out if it is a Get, Put, or Post (we don't care about any other ones)
    HttpMethod = string:substr(Packet, 1, 4),   
    case HttpMethod of 
	"GET " -> doHttpGetMethod(Conn);
	"PUT " -> doHttpPutMethod(Conn, Packet);
	"POST" -> doHttpPostMethod(Conn, Packet);          
	_ -> gen_tcp: send(Conn, response("ERROR.  This HttpMethod is not allowed."))
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


doHttpGetMethod(Conn)->
    getLedPid() ! {is_pin_on, 24, self()},
    receive 
	{led_pin_result, 24, IsBlueOn}->
	    io:fwrite(atom_to_list(IsBlueOn)),
	    case IsBlueOn of
		true -> ValueToPrint = "On";
		false -> ValueToPrint = "Off";
		_ -> ValueToPrint = "ERROR - disconnected!"
	    end
    after
	500 ->
	    ValueToPrint = "ERROR - no response from LEDS module"
    end,   
    
    gen_tcp:send(Conn, response("The value is: <h2>" ++ getTheColor() ++ "</h2><br/><br/><br/>
                                         <form method='POST'> 
                                             Entry: <input type='text' name='MyEntry' />
                                             <input type='submit' />
                                         </form>

                                         <form method='POST'>
                                             hello
                                             <input type='hidden' name='MyEntry' value='ChangeBlueLed'/> 
                                             <input type='submit' value='Turn LED " ++ ValueToPrint ++ "' />
                                         </form>")).


doHttpPutMethod(Conn, Packet)->
    PositionBeforeHttp = string:str(Packet, " HTTP/1") - string:len(" HTTP/1") + 2,
    Request = string:substr(Packet, 5, PositionBeforeHttp),
    first:setTheColor(string:substr(Request,2)),
    gen_tcp:send(Conn, response("Yeah we set it, up for ya")).


doHttpPostMethod(Conn, Packet)->
    Request = string:substr(Packet, 6),
    Property = "MyEntry=",
    io:fwrite("I'm in the post method handler\n"),
    PositionOfMyEntry = string:rstr(Request, Property),
    LengthOfMyEntry = string:len(Property),
    io:fwrite("This is the positionfoMyEntry: "++erlang:integer_to_list(PositionOfMyEntry)),
    MyEntry = string:substr(Request, PositionOfMyEntry + LengthOfMyEntry),
    io:fwrite(MyEntry),
    case MyEntry =:= "ChangeBlueLed" of
	true ->
	    getLedPid() ! {change_led, 24},
            doHttpGetMethod(Conn);
	false ->
	    gen_tcp:send(Conn, response("We see you posted  this: <br/>"
					++MyEntry 
					++ "<br/><br/><h2>So we changed the value to "
					++MyEntry
					++"!!</h2><br/><br/><br/><br/><a href='/'>Click to Check and See</a>"
					++"<br/><br/><br/>"
					++Packet)),
	    webs:setTheColor(MyEntry)
    end.





response(Str) ->
    B = iolist_to_binary(Str),
    iolist_to_binary(
      io_lib:fwrite(
         "HTTP/1.0 200 OK\nContent-Type: text/html\nContent-Length: ~p\n\n~s",
         [size(B), B])).


