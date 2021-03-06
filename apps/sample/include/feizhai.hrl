-ifndef(FEIZHAI_HRL).
-define(FEIZHAI_HRL, true).

-include_lib("kvs/include/kvs.hrl").

-type public_token() :: binary().
-type private_token() :: binary().
-type lati() :: number(). %-90.0 .. 90.0.
-type longti() :: number(). %-180.0 .. 180.0.
-type times_needed() :: pos_integer().
-type geohash() :: binary().
-type progre() :: {non_neg_integer()|done, [{{lati(), longti()}, geohash(), calendar:datetime()}] }.
-type progre_validator() :: fun((...) -> integer() | boolean() ).

-record(feizhai, {?ITERATOR(feed, true),
		%feizhai_id,
		public_token :: public_token(),
		private_token :: private_token(),
		last_active = {{1970,1,1},{0,0,0}} :: calendar:datetime(),
		ach_progress_ids = [] % list of id to TABLE ach_progress
		}).
-record(achieves, {?ITERATOR(feed, true),
		%achieve_id,
		   % per achieve validate fun() needed
		description = <<>>,
		times_needed :: times_needed(),
		precondition = [],  % other achieves as precondition
		validator :: progre_validator()
		}).

-record(ach_progress, {?ITERATOR(feed, true),
		%progress_id
		   % maybe add a feizhai_id??? no need?
		achieve_id,
		progre = {0, []} :: progre() % {times_done, [{{lati,longti}, geohash, time}] }
			}).

-endif.
