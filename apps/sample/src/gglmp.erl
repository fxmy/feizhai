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
infoWindowContent() -> wf:to_list(wf:render(#panel{id=infowindow,body=[
%					      #textbox{id=wf:state(achieve)},
%					      #hidden{id=wf:state(lan),disabled=true},
%					      #hidden{id=wf:state(lat),disabled=true},
%					      #hidden{id=wf:state(validt),disabled=true},
%					      #button{body= <<"成就get"/utf8>>,postback=newachieve}
					     ]})).

api_event(Func,Args,_Cx) -> wf:info(?MODULE, "api_event: ~p,~p~n", [Func,Args]),
			    wf:insert_bottom(infowindow,#textbox{}),
			    wf:insert_bottom(infowindow,#button{body= <<"成就get"/utf8>>}).

event(newachieve) -> wf:info(?MODULE,"New Achieve~n",[]);
event(btn) -> wf:wire("console.log('btn!');"),
	      wf:state(achieve,wf:temp_id()),wf:state(lan,wf:temp_id()),wf:state(lat,wf:temp_id()),wf:state(validt,wf:temp_id()),
	      wf:wire(#api{name=apiName}),
	      wf:wire("var hndlLctnErr = new Function('a','b','c','b.setPosition(c);b.setContent(a ? \"Error: The Geolocation service failed.\" : \"Error: Your browser doesn`t support geolocation.\");');
		      console.log('0');
var infoWindow = new google.maps.InfoWindow({map: map});
		      console.log('1');
if (navigator.geolocation) {
    navigator.geolocation.getCurrentPosition(function(position) {
		      console.log('2');
      var pos = {
        lat: position.coords.latitude,
        lng: position.coords.longitude
      };
		      console.log('3');

      infoWindow.setPosition(pos);
      infoWindow.setContent('Location found."++infoWindowContent()++"');
      map.setCenter(pos);
      apiName(pos);
    }, function() {
      hndlLctnErr(true, infoWindow, map.getCenter());
    });
  } else {
    // Browser doesn't support Geolocation
    hndlLctnErr(false, infoWindow, map.getCenter());
  }");
event(init) ->
	wf:wire("console.log('!!!event init!!!')"),
	wf:info(?MODULE,"~p-> init!~n",[self()]);
event(terminate) ->
	wf:info(?MODULE,"~p-> Terminate!~n",[self()]);
event(Event) -> wf:info(?MODULE,"~p-> Unknown Event: ~p~n",[self(),Event]).
