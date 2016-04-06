-module(index).
-compile(export_all).
-include_lib("n2o/include/wf.hrl").
-include_lib("nitro/include/nitro.hrl").

peer()    -> wf:to_list(wf:peer(?REQ)).
message() -> wf:js_escape(wf:html_encode(wf:to_list(wf:q(message)))).
main()    -> #dtl{file="index",app=sample,bindings=[{body,body()}]}.
body()    -> [#panel{class=["fixed-action-btn"],style=["bottom: 25px; right: 25px;"],body=[
		#link{id=aaa,class=["btn-floating btn-large waves-effect waves-light red"],postback=btn,source=[message],body=[
			#i{class=["material-icons"],body=["add"]}]}
              ]},
	      #panel{id=history},
	      #textbox{id=message},
	      #button{id=send,body="Chat",postback=chat,source=[message]},
		%#textbox{id=nitro:temp_id(),disabled=true,style=["visibility: hidden;"]},
		%#button{body="crdrcd"},
		#hidden{id=kkk,disabled=true},
		#button{body=nitro:temp_id(),source=[message],postback=kkk},
		#textbox{id=qqq,disabled=true}].


event(init) -> wf:reg(room);
event(chat) -> wf:send(room,{client,{peer(),message()}});
event(btn) ->  event(chat);
event(kkk) -> wf:wire(#jq{target=kkk,property=value,right=message()}),
	wf:wire(#jq{target=qqq,property=value,right=#jq{target=kkk,property=value}});
	%wf:wire(#jq{target=qqq,property=value,right=#jq{target=kkk,property=value}});
event({client,{P,M}}) -> wf:insert_bottom(history,#panel{id=history,body=[P,": ",M,#br{}]});
event(Event) -> wf:info(?MODULE,"Unknown Event: ~p~n",[Event]).
