-module(gglmp).
-compile(export_all).
-include_lib("n2o/include/wf.hrl").
-include_lib("nitro/include/nitro.hrl").

main()    -> #dtl{file="gglmp",app=sample, bindings=[{authkey,authkey()}, {presentmap,presentmap()}, {initmapfunc,initmapfunc()},{body,body()}]}.
body() -> [#panel{id=map},
	   #panel{class=["fixed-action-btn"],style=["bottom: 25px; right: 48px;"],body=[
		#link{class=["btn-floating btn-large waves-effect waves-light red"],postback=btn,body=[
			#i{class=["material-icons"],body=["add"]}]}
              ]}].
authkey() -> "AIzaSyAAbNcNrZoGgi8YMdZ98Z3UGPXxM8PsbBU".
presentmap() -> "XiaoSuiGu".
initmapfunc() -> "var map;function "++presentmap()++"() {map = new google.maps.Map(document.getElementById('map'),{center: {lat: 60.192059, lng: 24.945831},zoom: 12,mapTypeControl:false,fullscreenControl:true});}".
infoWindowContent() ->
	wf:to_list(wf:render(#blockquote{body= memes:rand(),style=["font-weight: bold; margin-bottom: 0px;"]})) ++ wf:to_list(wf:render(#panel{id=wf:state(infowindow)})).
tmpidcmpac() -> lists:delete($-, wf:temp_id()).

api_event(Func,Args,_Cx) ->
	wf:info(?MODULE, "api_event: ~p,~p~n", [Func,Args]),
	wf:insert_bottom(wf:state(infowindow),#hidden{id=wf:state(validt),disabled=true,value=wf:pickle(wf:state(validt_content))}),
	wf:insert_bottom(wf:state(infowindow),#textbox{id=wf:state(achieve)}),
	wf:insert_bottom(wf:state(infowindow),#button{body= <<"成就get"/utf8>>,postback=newachieve,source=[wf:state(achieve),wf:state(validt)],class=["btn waves-effect waves-light"]}).

event(newachieve) ->
	wf:info(?MODULE,"New Achieve:~p,~p,~p~n",[wf:q(wf:state(achieve)),wf:depickle(wf:q(wf:state(validt))),wf:state(validt_content)]);
event(btn) ->
	wf:wire("console.log('btn!');"),
	wf:state(infowindow,tmpidcmpac()),
	wf:state(apiName,tmpidcmpac()),
	wf:state(achieve,tmpidcmpac()),
	wf:state(validt,tmpidcmpac()),
	wf:state(validt_content,crypto:rand_bytes(4)),
	wf:wire(#api{name=wf:state(apiName)}),
	wf:wire("var hndlLctnErr = new Function('a','b','c','b.setPosition(c);b.setContent(a ? \"Error: The Geolocation service failed.\" : \"Error: Your browser doesn`t support geolocation.\");');
var infoWindow = new google.maps.InfoWindow({map: map});
if (navigator.geolocation) {
    navigator.geolocation.getCurrentPosition(function(position) {
      var pos = {
        lat: position.coords.latitude,
        lng: position.coords.longitude
      };

      infoWindow.setPosition(pos);
      infoWindow.setContent('"++infoWindowContent()++"');
      map.setCenter(pos);
      "++wf:state(apiName)++"(pos);
    }, function() {
      hndlLctnErr(true, infoWindow, map.getCenter());
    });
  } else {
    // Browser doesn't support Geolocation
    hndlLctnErr(false, infoWindow, map.getCenter());
  }");
event(init) ->
	wf:wire("console.log('!!!event init!!!');"),
	wf:info(?MODULE,"~p-> init!~n",[self()]);
event(terminate) ->
	wf:info(?MODULE,"~p-> Terminate!~n",[self()]);
event(Event) -> wf:info(?MODULE,"~p-> Unknown Event: ~p~n",[self(),Event]).
