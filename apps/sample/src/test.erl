-module(test).
-compile([export_all]).
-include_lib("sample/include/feizhai.hrl").

go(N) when is_integer(N) ->
	[begin
		 receive
		 after 3000 ->
					feizhai:activity(<<"fake">>,<<"fake">>)
		 end
	 end || _X <- lists:seq(1,N)].

%notify() ->
%	K = kvs:entries(kvs:get(feed, feizhai),feizhai, 100),
%	case K of
%		[] ->
%			skip;
%		[#feizhai{public_token=PuT,private_hash=PrT}|_] ->
%			feizhai:activity(PuT,PrT)
%	end.

secIndex() ->
	kvs:add(#achieves{id=kvs:next_id("achieves",1), description= <<"the world!">>, times_needed= 5}),
	kvs:add(#ach_progress{id=kvs:next_id("ach_progress", 1), feed_id= {ach_progress,<<"fei">>}, achieve_id=1, progre={1, [ {233,233}, <<"magicgeohash">>, calendar:universal_time() ] } }),
	kvs:index(ach_progress, achieve_id, 1).
