-module(feizhai).
-compile([export_all]).
%-export([metainfo/0]).

-include_lib("sample/include/feizhai.hrl").
-include_lib("kvs/include/metainfo.hrl").

metainfo() ->
	#schema{name=kvs, tables=[
				#table{name=feizhai, container=feed, fields=record_info(fields, feizhai),keys=[public_token]},
				#table{name=achieves, container=feed, fields=record_info(fields, achieves)},
			#table{name=ach_progress, container=feed, fields=record_info(fields, ach_progress),keys=[achieve_id]}
				 ]}.

snip() ->
	kvs:entries(kvs:get(feed,achieves), achievees, 10),
	F = fun() -> ok end,
	kvs:add(#achieves{id = kvs:next_id(achieves,1), description = <<"wft诶嘿嘿"/utf8>>, times_needed = 3, validator = F}).

activity(PubToken,PriToken) ->
	case validate_cookie(PubToken,PriToken) of
		{error,_Reason} ->
			CookieConfig = wf:config(sample, cookie, open),
			if
				CookieConfig==open ->
					{PuT,PrT}=feizhai:new_feizhai(),
					bump(#feizhai{public_token=PuT,private_token=PrT});
				true ->
					{error, cookie_closed}
			end;
		{ok,FZ=#feizhai{}} ->
			bump(FZ)
	end.

validate_cookie(PubToken,PriToken) when is_binary(PubToken) andalso is_binary(PriToken) ->
	case kvs:index(feizhai, public_token, PubToken) of
		[] ->
			{error,not_found};
		[FZ=#feizhai{public_token=PubToken,private_token=PriToken}] ->
			{ok,FZ};
		_ ->
			{error,auth_fail}
	end;
validate_cookie(_PubToken,_PriToken) ->
	{error,badarg}.

% new face in town
bump(#feizhai{id=undefined,prev=undefined,next=undefined,public_token=PuT,private_token=PrT}=FZ) ->
	NewLA = calendar:universal_time(),
	case kvs:get(feed, feizhai) of
		{error,not_found} -> % first in town
			kvs:add(FZ#feizhai{id=Id=kvs:next_id(feizhai,1),last_active=NewLA}),
			wf:send(channel_reap,{lastFZchange, Id, NewLA});
		{ok,_} ->
			kvs:add(FZ#feizhai{id=kvs:next_id(feizhai,1),last_active=NewLA})
	end,
	{ok,{NewLA,PuT,PrT}};
% old face
bump(#feizhai{id=Id,prev=undefined,next=undefined,public_token=PuT,private_token=PrT}=FZ) ->
	NewLA = calendar:universal_time(),
	wf:send(channel_reap,{lastFZchange,Id,NewLA}),
	kvs:remove(feizhai,Id),
	kvs:add(FZ#feizhai{last_active=NewLA}),
	{ok,{NewLA,PuT,PrT}};
bump(#feizhai{id=Id,prev=undefined,next=Next,public_token=PuT,private_token=PrT}=FZ) ->
	{ok,#feizhai{id=Next,last_active=NLA}} = kvs:get(feizhai,Next),
	wf:send(channel_reap,{lastFZchange,Next,NLA}),
	kvs:remove(feizhai,Id),
	kvs:add(FZ#feizhai{last_active=NewLA=calendar:universal_time()}),
	{ok,{NewLA,PuT,PrT}};
bump(#feizhai{id=Id,public_token=PuT,private_token=PrT}=FZ) ->
	kvs:remove(feizhai,Id),
	kvs:add(FZ#feizhai{last_active=NewLA=calendar:universal_time()}),
	{ok,{NewLA,PuT,PrT}}.

-spec new_feizhai() -> {binary(),binary()}.
new_feizhai() ->
	PublicToken = new_token(10),
	PrivateToken = new_token(10),
	{PublicToken,PrivateToken}.

-spec new_token( pos_integer() ) -> binary().
new_token(Bytes) ->
	B64 = base64:encode(crypto:strong_rand_bytes(Bytes)),
	binary:replace(B64, [<<"=">>,<<"/">>,<<"+">>], <<>>, [global]).
