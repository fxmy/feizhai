-module(feizhai).
-compile([export_all]).
%-export([metainfo/0]).

-include_lib("sample/include/feizhai.hrl").
-include_lib("kvs/include/metainfo.hrl").

metainfo() ->
	#schema{name=kvs, tables=[
				#table{name=feizhai, container=feed, fields=record_info(fields, feizhai)},
				#table{name=achieves, container=feed, fields=record_info(fields, achieves)},
				#table{name=ach_progress, container=feed, fields=record_info(fields, ach_progress)}
				 ]}.

snip() ->
	kvs:entries(kvs:get(feed,achieves), achievees, 10),
	F = fun() -> ok end,
	kvs:add(#achieves{id = kvs:next_id(achieves,1), description = <<"wft诶嘿嘿"/utf8>>, times_needed = 3, validator = F}).

-spec new_feizhai() -> {binary(),binary(),calendar:datetime()}.
new_feizhai() ->
	PublicToken = new_token(10),
	PrivateToken = new_token(10),
	%LifeSpan = calendar:gregorian_seconds_to_datetime( calendar:datetime_to_gregorian_seconds( calendar:universal_time()) + wf:config(sample,feizhai_life, 864000)),
	LastAct = calendar:universal_time(),
	Feizhai = #feizhai{id=PublicToken,public_token=PublicToken,private_token=PrivateToken,last_active=LastAct},
	kvs:add(Feizhai),
	{PublicToken,PrivateToken,LastAct}.

-spec new_token( pos_integer() ) -> binary().
new_token(Bytes) ->
	B64 = base64:encode(crypto:strong_rand_bytes(Bytes)),
	binary:replace(B64, [<<"=">>,<<"/">>,<<"+">>], <<>>, [global]).

