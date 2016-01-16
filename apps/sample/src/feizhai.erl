-module(feizhai).
-compile([export_all]).

-include_lib("apps/sample/include/feizhai.hrl").
-include_lib("kvs/include/metainfo.hrl").

metainfo() ->
	#schema{name=kvs, tables=[
				#table{name=feizhai, container=feed, fields=record_info(fields, feizhai)},
				#table{name=achieves, container=feed, fields=record_info(fields, achieves)},
				#table{name=achieve_progress, container=feed, fields=record_info(fields, achieve_progress)}
				 ]}.
