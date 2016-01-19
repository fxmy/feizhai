-module(feizhai).
-compile([export_all]).
%-export([metainfo/0]).

-include_lib("sample/include/feizhai.hrl").
-include_lib("kvs/include/metainfo.hrl").

metainfo() ->
	#schema{name=kvs, tables=[
				#table{name=feizhai, container=feed, fields=record_info(fields, feizhai)},
				#table{name=achieves, container=feed, fields=record_info(fields, achieves)},
				#table{name=achieve_progress, container=feed, fields=record_info(fields, achieve_progress)}
				 ]}.

-spec new_feizhai() -> {binary(),binary(),calendar:datetime()}.
new_feizhai() ->
	PublicToken = new_token(10),
	PrivateToken = new_token(10),
	LifeSpan = calendar:gregorian_seconds_to_datetime( calendar:datetime_to_gregorian_seconds( calendar:universal_time()) + wf:config(sample,feizhai_life, 864000)),
	{PublicToken,PrivateToken,LifeSpan}.

-spec new_token( pos_integer() ) -> binary().
new_token(Bytes) ->
	B64 = base64:encode(crypto:strong_rand_bytes(Bytes)),
	binary:replace(B64, [<<"=">>,<<"/">>,<<"+">>], <<>>, [global]).

