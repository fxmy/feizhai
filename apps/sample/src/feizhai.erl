-module(feizhai).
-compile([export_all]).
%-export([metainfo/0]).

-define(BCRYPT_WORKFACTOR, 4).
-define(WORDS_LIMIT_BYTES, 140*3).

-include_lib("sample/include/feizhai.hrl").
-include_lib("kvs/include/metainfo.hrl").

metainfo() ->
	#schema{name=kvs, tables=[
				#table{name=feizhai, container=feed, fields=record_info(fields, feizhai),keys=[public_token]},
				#table{name=achieves, container=feed, fields=record_info(fields, achieves)},
				#table{name=ach_progress, container=feed, fields=record_info(fields, ach_progress),keys=[achieve_id]},
				#table{name=nichijou, container=feed, fields=record_info(fields, nichijou)}
				 ]}.

snip() ->
	kvs:entries(kvs:get(feed,achieves), achievees, 10),
	F = fun() -> ok end,
	kvs:add(#achieves{id = kvs:next_id(achieves,1), description = <<"wft诶嘿嘿"/utf8>>, times_needed = 3, validator = F}).

add_feizhai_property(PubToken,PriToken,ach_progress,Value) when is_binary(PubToken) andalso is_binary(PriToken) ->
	case validate_cookie(PubToken,PriToken) of
		{error, _Reason} -> ignore;
		{ok, FZ=#feizhai{}} ->
			add_feizhai_property(FZ,ach_progress,Value)
	end;
add_feizhai_property(PubToken,PriToken,nichijou,Value) when is_binary(PubToken) andalso is_binary(PriToken) ->
	case validate_cookie(PubToken,PriToken) of
		{error, _Reason} -> ignore;
		{ok, FZ=#feizhai{}} ->
			add_feizhai_property(FZ,nichijou,Value)
	end;
add_feizhai_property(_PubToken,_PriToken,_Field,_Value) when is_binary(_PubToken) andalso is_binary(_PriToken) ->
	ignore.

add_feizhai_property(ID,ach_progress,Value) when is_integer(ID) ->
	case kvs:get(feizhai, ID) of
		{error, not_found} -> ignore;
		{ok, FZ=#feizhai{}} ->
			add_feizhai_property(FZ,ach_progress,Value)
	end;
add_feizhai_property(ID,nichijou,Value) when is_integer(ID) ->
	case kvs:get(feizhai, ID) of
		{error, not_found} -> ignore;
		{ok, FZ=#feizhai{}} ->
			add_feizhai_property(FZ,nichijou,Value)
	end;
add_feizhai_property(FZ=#feizhai{ach_progress_ids=Old},ach_progress,Value) ->
	kvs:put(FZ#feizhai{ach_progress_ids=[Value|Old]});
add_feizhai_property(FZ=#feizhai{nichijou_ids=Old},nichijou,Value) ->
	kvs:put(FZ#feizhai{nichijou_ids=[Value|Old]});
add_feizhai_property(_FZ=#feizhai{},_Field,_Value) ->
	ignore;
add_feizhai_property(_ID,_Field,_Value) when is_integer(_ID) ->
	ignore.

add_nichijou(PubToken,PriToken,Content,Lat,Lng) when is_binary(PubToken),is_binary(PriToken),is_binary(Content),is_number(Lat),is_number(Lng) ->
	case validate_cookie(PubToken,PriToken) of
		{error,_Reason} -> ignore;
		{ok, FZ=#feizhai{id=FZ_Id}} ->
			kvs:add(#nichijou{id=NichijouID=kvs:next_id("nichijou",1),feed_id=nichijou,feizhai_id=FZ_Id,content=Content,lat=Lat,lng=Lng,created=calendar:universal_time()}),
			add_feizhai_property(FZ,nichijou,NichijouID),
			{ok,Geohash} = geohash:encode(Lat,Lng,12),
			geocache:newentry(Geohash,{nichijou,NichijouID})
	end.

activity(PubToken,PriToken) ->
	case validate_cookie(PubToken,PriToken) of
		{error,_Reason} ->
			CookieConfig = wf:config(sample, cookie, open),
			if
				CookieConfig==open ->
					{PuT,PrT,PrH}=feizhai:new_feizhai(),
					{ok,NewLA} = bump(#feizhai{public_token=PuT,private_hash=PrH}),
					{setcookie, PuT, PrT, NewLA};
				true ->
					{error, cookie_closed}
			end;
		{ok,FZ=#feizhai{}} ->
			{ok,NewLA} = bump(FZ),
			{setcookie, keep, keep, NewLA}
	end.

validate_cookie(PubToken,PriToken) when is_binary(PubToken) andalso is_binary(PriToken) ->
	case kvs:index(feizhai, public_token, PubToken) of
		[] ->
			{error,not_found};
		[FZ=#feizhai{public_token=PubToken,private_hash=PriHash}] ->
			{ok,NewHash} = bcrypt:hashpw(PriToken,PriHash),
			case verify_in_constant_time(NewHash,PriHash) of
				true ->
					{ok,FZ};
				false ->
					{error,auth_fail}
			end
	end;
validate_cookie(_PubToken,_PriToken) ->
	{error,badarg}.

% new face in town
bump(#feizhai{id=undefined,prev=undefined,next=undefined}=FZ) ->
	NewLA = calendar:universal_time(),
	case kvs:get(feed, feizhai) of
		{error,not_found} -> % first in town
			kvs:add(FZ#feizhai{id=Id=kvs:next_id(feizhai,1),last_active=NewLA}),
			wf:send(channel_reap,{lastFZchange, Id, NewLA});
		{ok,_} ->
			kvs:add(FZ#feizhai{id=kvs:next_id(feizhai,1),last_active=NewLA})
	end,
	{ok,NewLA};
% old face
bump(#feizhai{id=Id,prev=undefined,next=undefined}=FZ) ->
	NewLA = calendar:universal_time(),
	wf:send(channel_reap,{lastFZchange,Id,NewLA}),
	kvs:remove(feizhai,Id),
	kvs:add(FZ#feizhai{last_active=NewLA}),
	{ok,NewLA};
bump(#feizhai{id=Id,prev=undefined,next=Next}=FZ) ->
	{ok,#feizhai{id=Next,last_active=NextLA}} = kvs:get(feizhai,Next),
	wf:send(channel_reap,{lastFZchange,Next,NextLA}),
	kvs:remove(feizhai,Id),
	kvs:add(FZ#feizhai{last_active=NewLA=calendar:universal_time()}),
	{ok,NewLA};
bump(#feizhai{id=Id}=FZ) ->
	kvs:remove(feizhai,Id),
	kvs:add(FZ#feizhai{last_active=NewLA=calendar:universal_time()}),
	{ok,NewLA}.

-spec new_feizhai() -> {binary(),binary(),binary()}.
new_feizhai() ->
	PublicToken = new_token(10),
	PrivateToken = new_token(10),
	{ok,Salt} = bcrypt:gen_salt(?BCRYPT_WORKFACTOR),
	{ok, PriHash} = bcrypt:hashpw(PrivateToken, Salt),
	{PublicToken,PrivateToken,list_to_binary(PriHash)}.

-spec new_token( pos_integer() ) -> binary().
new_token(Bytes) ->
	B64 = base64:encode(crypto:strong_rand_bytes(Bytes)),
	binary:replace(B64, [<<"=">>,<<"/">>,<<"+">>], <<>>, [global]).

%% Verifies two hashes for matching purpose, in constant time. That allows
%% a safer verification as no attacker can use the time it takes to compare hash
%% values to find an attack vector (past figuring out the complexity)
verify_in_constant_time([X|RestX], [Y|RestY], Result) ->
	verify_in_constant_time(RestX, RestY, (X bxor Y) bor Result);
verify_in_constant_time([], [], Result) ->
	Result == 0.

verify_in_constant_time(X, Y) when is_list(X) and is_list(Y) ->
	case length(X) == length(Y) of
		true ->
			verify_in_constant_time(X, Y, 0);
		false ->
			false
	end;
verify_in_constant_time(X, Y) when is_binary(X) -> verify_in_constant_time(wf:to_list(X), Y);
verify_in_constant_time(X, Y) when is_binary(Y) -> verify_in_constant_time(X, wf:to_list(Y));
verify_in_constant_time(_X, _Y) -> false.

words_limit(Binary) when is_binary(Binary) ->
	words_limit(Binary, ?WORDS_LIMIT_BYTES).

words_limit(Binary, Limit) when is_integer(Limit) ->
	case byte_size(Binary) > Limit of
		false ->
			Binary;
		true ->
			NewBin = binary:part(Binary, {0,Limit}),
			case unicode:characters_to_binary(NewBin) of
				{error, _Decoded, _RestBin} ->
					{error, illegal_encode};
				{incomplete, Decoded, _RestBin} ->
					<<Decoded/binary, "..."/utf8>>;
				Decoded ->
					<<Decoded/binary, "..."/utf8>>
			end
	end.
