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

marker_with_info(Lat,Lng,Who,Content) ->
	"new google.maps.Marker({
    position: {lat: "++wf:to_list(Lat)++", lng: "++wf:to_list(Lng)++"},
    map: map,
    title: '"++wf:to_list(Who)++":\n"++wf:to_list(Content)++"'
  });".

api_event(Func,Args,_Cx) ->
	ApiName = wf:state(apiName),
	if ApiName == Func->
		   Pos = jsone:decode(wf:to_binary(Args),[{object_format, map}]),
		   wf:info(?MODULE, "api_event: ~p,~p~n", [Func,Pos]),
		   wf:state(lat, maps:get(<<"lat">>, Pos)),
		   wf:state(lng, maps:get(<<"lng">>, Pos)),
		   wf:insert_bottom(wf:state(infowindow),#hidden{id=wf:state(validt),disabled=true,value=wf:pickle(wf:state(validt_content))}),
		   wf:insert_bottom(wf:state(infowindow),#textbox{id=wf:state(nichijou)}),
		   wf:insert_bottom(wf:state(infowindow),#button{body= <<"成就get"/utf8>>,postback=nichijou,source=[wf:state(nichijou),wf:state(validt)],class=["btn waves-effect waves-light"]});
	   true ->
		   wf:info(?MODULE, "apiName mismatch, expect ~p, got ~p~n", [ApiName,Func]),
		   wf:wire("console.log('uccu apiName mismatch, ugly');")
	end.

event(nichijou) ->
	{IP,_Port} = wf:peer(?REQ),
	case antiipspam:checkspam(IP) of
		nospam ->
			ServerTK = wf:state(validt_content),
			ClientTK = wf:depickle(wf:q(wf:state(validt))),
			Content = feizhai:words_limit(wf:q(wf:state(nichijou))),
			if
				ServerTK==undefined orelse ClientTK==undefined ->
					wf:info(?MODULE, "Server or Client TK undefined~n",[]);
				ServerTK == ClientTK ->
					PubTK = case wf:cookie("pubtk") of
						{pubtk, Pub, _PathPub, _TTLPub} -> Pub;
						_ -> false
					end,
					PriTK = case wf:cookie("pritk") of
						{pritk, Pri, _PathPri, _TTLPri} -> Pri;
						_ -> false
					end,
					case feizhai:activity(PubTK,PriTK) of
						{error, cookie_closed} ->
							wf:wire(#alert{text="uccu no cookie ugly~"});
						{setcookie, keep, keep, _NewLastActive} ->
							wf:cookie("pubtk",wf:to_list(PubTK),"/",wf:config(sample,feizhai_life,5*60)),
							wf:cookie("pritk",wf:to_list(PriTK),"/",wf:config(sample,feizhai_life,5*60)),
							wf:wire(marker_with_info(wf:state(lat),wf:state(lng),PubTK,Content));
						{setcookie, NewPubTK, NewPriTK, _NewLastActive} ->
							wf:cookie("pubtk",wf:to_list(NewPubTK),"/",wf:config(sample,feizhai_life,5*60)),
							wf:cookie("pritk",wf:to_list(NewPriTK),"/",wf:config(sample,feizhai_life,5*60)),
							wf:wire(marker_with_info(wf:state(lat),wf:state(lng),NewPubTK,Content))
					end,
					wf:info(?MODULE,"New Achieve:~p,~p,~p~n",[wf:q(wf:state(nichijou)),ServerTK,ClientTK]);
				true ->
					wf:info(?MODULE, "ClientTK mismatch, expect ~p, got ~p~n", [ServerTK, ClientTK])
			end;
		spam ->
			wf:wire(#alert{text="uccu drown in water ugly~"})
	end,
	antiipspam:newpost(IP),
	wf:state(validt, undefined),
	wf:state(validt_content, undefined);

event(btn) ->
	wf:wire("console.log('btn!');"),
	wf:state(infowindow,tmpidcmpac()),
	wf:state(apiName,tmpidcmpac()),
	wf:state(nichijou,tmpidcmpac()),
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
event({client, {<<"timezone">>,TZ}}) -> wf:state(<<"timezone">>, TZ);
event(init) ->
	wf:wire("console.log('!!!event init!!!');"),
	wf:wire("ws.send(enc(tuple(atom('client'), tuple(bin('timezone'), number(new Date().getTimezoneOffset())))));"),
	wf:info(?MODULE,"~p-> init!~n",[self()]);
event(terminate) ->
	wf:info(?MODULE,"~p-> Terminate!~n",[self()]);
event(Event) -> wf:info(?MODULE,"~p-> Unknown Event: ~p~n",[self(),Event]).
