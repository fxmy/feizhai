-module(test).
-compile([export_all]).
-include_lib("sample/include/feizhai.hrl").

go() ->
	{PuTo, _PrTo, LADT} = feizhai:new_feizhai(),
	feizhai_reaper:update_fz_target(PuTo,LADT),
	[begin
		 receive
		 after 3000 ->
			       feizhai:new_feizhai()
		 end
	 end || _X <- lists:seq(1,5)].

notify() ->
	[#feizhai{public_token=PuTo,next=NextId} =A|_] = kvs:entries(kvs:get(feed, feizhai),feizhai, 100),
	{ok, #feizhai{id=Id, last_active=La}} = kvs:get(feizhai, NextId),
	wf:send(channel_reap,{lastFZchange, Id, La}),
	io:format("========~n~p -> ~p~n=======~n",[PuTo, Id]),

	kvs:remove(feizhai, PuTo),
	kvs:add(A).

secIndex() ->
	kvs:add(#achieves{id=kvs:next_id("achieves",1), description= <<"the world!">>, times_needed= 5}),
	kvs:add(#ach_progress{id=kvs:next_id("ach_progress", 1), feed_id= {ach_progress,<<"fei">>}, achieve_id=1, progre={1, [ {233,233}, <<"magicgeohash">>, calendar:universal_time() ] } }),
	kvs:index(ach_progress, achieve_id, 1).
