-module(leds).

-export([start/0, listen/2, sendApi/2, sendHeartbeat/0, doHeartbeater/0, setupPins/0]).

listen(OldGpio27, OldGpio9)->
    receive
	finished ->
	    io:fwrite("Finished Listening for messages. ")
    after 
	100  ->
	    Gpio27 = gpio:read(27),
	    if (Gpio27 =:= 0) ->		    
		    gpio:write(4, 0),
		    gpio:write(22, 0);		    
            (Gpio27 =:= 1) ->
		    gpio:write(4, 1),
		    gpio:write(22, 1)
    	    end,
	    
	    Gpio9 = gpio:read(9),
	    if (Gpio9 =:= 0) ->		    
		    gpio:write(17, 0),
		    gpio:write(10, 0);		    
            (Gpio9 =:= 1) ->
		    gpio:write(17, 1),
		    gpio:write(10, 1)
    	    end,

	    case OldGpio27 =:= Gpio27 of
	        false -> sendApi(Gpio27, "27");
	        true -> io:fwrite("change in 27")
	    end,
	    case OldGpio9 =:= Gpio9 of
		false -> sendApi(Gpio9, "9");
		true -> io:fwrite("change in 9")
	    end,

            CurrentColor = webs:getTheColor(),
	    if 
		(CurrentColor =:= "green") ->
		    gpio:write(24, 1),
		    gpio:write(25, 1);
	        (CurrentColor =/= "green") ->
		    gpio:write(24,0),
		    gpio:write(25,0)
	    end,

	    listen(Gpio27, Gpio9)
    end.

sendApi(1, PinNumber)->
    %httpc:request(post, {"http://192.168.1.4/PiPin/Create/?IsPressed=true&IsLetGo=false&Message=Pin27", [], "application/json", "{}" }, [], []);
    httpc:request(post, {string:concat("http://nasbowitnbhar/PiPin/Create/?IsPressed=true&IsLetGo=false&Message=P", PinNumber), [], "application/json", "{}" }, [], []);
sendApi(0, PinNumber)->
     %httpc:request(post, {"http://192.168.1.4/PiPin/Create/?IsPressed=false&IsLetGo=true&Message=Pin27", [], "application/json", "{}" }, [], []).
    httpc:request(post, {string:concat("http://nasbowitnbhar/PiPin/Create/?IsPressed=false&IsLetGo=true&Message=P", PinNumber), [], "application/json", "{}" }, [], []).

sendHeartbeat()->
    httpc:request(post, {"http://nasbowitnbhar/PiPinHeartbeat/Create/", [], "application/json", "{}" }, [], []).
    		   
doHeartbeater()->
    receive
	finished ->
	    io:fwrite("finished heartbeating ")
    after 10000 ->
	    sendHeartbeat(),
	    doHeartbeater()
    end.

setupPins()->
    gpio_sup:start_link([{4, output}, {17, output}, {27, input}, {22, output}, {10, output}, {9, input}, {24, output}, {25, output}]),
    gpio:write(4, 0),
    gpio:write(17, 1),
    gpio:write(22, 1),
    gpio:write(10, 0),
    gpio:write(24, 0),
    gpio:write(25, 0),
    io:fwrite("Yeah baby, we set it up!   ").
        
loadGpioFiles()->
    code:add_pathsz(["deps/erlang_portutil/ebin", "deps/gproc/ebin", "deps/meck/ebin", "deps/pihwm/ebin", "ebin", "examples"]).


start() ->
    loadGpioFiles(),
    setupPins(),
    io:fwrite("Gonna create process and set it to start listening for button presses  "),   
    inets:start(),
    io:fwrite("getting initial gpio value "),
    InitialGpio27 = gpio:read(27),
    io:fwrite("the value is: "++ integer_to_list(InitialGpio27)),
    InitialGpio9 = gpio:read(9),
    sendApi(InitialGpio27, "27"), %send an initial pin value to change any previously stored value
    sendApi(InitialGpio9, "9"),
    sendHeartbeat(),          %send a heart beat immediately (so we don't have to wait the heartbeat timeout initially)
    register (myHeartbeat, spawn(test, doHeartbeater, [])),
    register (myListener, spawn(test, listen, [InitialGpio27, InitialGpio9])).
