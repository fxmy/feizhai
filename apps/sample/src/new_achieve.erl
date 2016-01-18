-module(new_achieve).
-compile(export_all).
-include_lib("n2o/include/wf.hrl").
-include_lib("nitro/include/nitro.hrl").
-include_lib("sample/include/feizhai.hrl").

main() -> #dtl{file="new_achieve", app=sample, bindings=[{body,body()} ]}.
body() -> [
	   #textbox{id=lati},
	   #textbox{id=longti},
	   #textbox{id=detail},
	   #button{id=send, body= <<"成就get"/utf8>>, postback=new_achieve, source=[lati,longti,detail]},
	   #panel{id=history}
	  ].

event(new_achieve) -> wf:info(?MODULE, "button_clicked in ~p: ~p ~p ~p", [self(), wf:q(lati),wf:q(longti),wf:q(detail)]),
		      wf:insert_top(history, #panel{id=history, body=[wf:q(lati),"_",wf:q(longti),"_",wf:q(detail),#br{}] });
event(Event) -> wf:info(?MODULE,"Unknown Event: ~p~n",[Event]).
