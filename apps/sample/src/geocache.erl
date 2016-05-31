-module(geocache).

-behaviour(gen_server).

-include_lib("kvs/include/metainfo.hrl").
-include_lib("sample/include/geocache.hrl").

%% API functions
-export([start_link/0, metainfo/0]).

%% gen_server callbacks
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).

-compile([export_all]).


%%%===================================================================
%%% API functions
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

newentry(Geohash, Value) when is_binary(Geohash) ->
	gen_server:cast(?MODULE, {newentry, Geohash, Value}).

getentry(Geohash) when is_binary(Geohash) ->
	gen_server:call(?MODULE, {getentry, Geohash}).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
init([]) ->
    {ok, trie:new()}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @spec handle_call(Request, From, State) ->
%%                                   {reply, Reply, State} |
%%                                   {reply, Reply, State, Timeout} |
%%                                   {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, Reply, State} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_call({getentry, Geohash}, _From, Trie) when is_binary(Geohash) ->
	GeoList = binary_to_list(Geohash),
	Top = trie:fold_match(GeoList, fun gether/3, [], Trie),
	Sub = trie:fold_match(GeoList++"*", fun gether/3, [], Trie),
	Total = Top++Sub,
	case Total of
		[] -> % time to check mnesia
		      % !!!mnesia dependency!!!
			Res = mnesia:async_dirty(fun mnesia_geoprefix_get/1, [GeoList]),
			NewTrie = lists:foldl(fun updatetrie/2,Trie,Res),
			ProgIds = lists:umerge([lists:sort(X)||#geocache{ach_progress_ids=X} <- Res]),
			Pairs = [{H,lists:reverse(lists:sort(X))} ||#geocache{geohash=H,ach_progress_ids=X} <- Res],
			{reply, Pairs, NewTrie};
		_ ->
			{reply, Total, Trie}
	end;
handle_call(Request, From, State) ->
	wf:info(?MODULE, "got unexpected call: ~p from~p~n", [Request, From]),
	{noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @spec handle_cast(Msg, State) -> {noreply, State} |
%%                                  {noreply, State, Timeout} |
%%                                  {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_cast({newentry, Geohash, Value}, Trie) when is_binary(Geohash) ->
	GeoList = binary_to_list(Geohash),
	case kvs:get(geocache, GeoList) of
		{error, not_found} ->
			kvs:put(#geocache{geohash=GeoList, ach_progress_ids=[Value]});
		{ok, #geocache{geohash=GeoList, ach_progress_ids=OldAcPrIds}} ->
			New = uappend(Value, OldAcPrIds),
			kvs:put(#geocache{geohash=GeoList, ach_progress_ids=New})
	end,
	NewTrie = case trie:is_key(GeoList,Trie) of
		false ->
			trie:prefix(GeoList, Value, Trie);
		true ->
			OldValues = trie:fetch(GeoList, Trie),
			NewValues = uappend(Value, OldValues),
			trie:store(GeoList, NewValues, Trie)
	end,
	{noreply, NewTrie};
handle_cast(Msg, State) ->
	wf:info(?MODULE, "got unexpected cast: ~p~n", [Msg]),
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_info(Info, State) ->
	wf:info(?MODULE, "got unexpected info: ~p~n", [Info]),
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
metainfo() ->
	#schema{name=kvs, tables=[
				  #table{name=geocache, fields=record_info(fields, geocache)}
				 ]}.

-spec uappend(any(), list()) -> list().
uappend(Value, List) when is_list(List) ->
	[Value| [X || X<-List, X =/=Value]].

-spec gether(Key::string(), Value::any(), Acc::list()) -> list().
gether(Key, Value, Acc) ->
	[{Key,Value}|Acc].

-spec mnesia_geoprefix_get(string()) ->list(). % |no_return(). ?
mnesia_geoprefix_get(Prefix) when is_list(Prefix) ->
	mnesia:match_object(#geocache{geohash= Prefix++'_', ach_progress_ids = '_'}).

updatetrie(#geocache{geohash=GeoList,ach_progress_ids=Values}, TrieIn) ->
	case trie:is_key(GeoList,TrieIn) of
		false ->
			trie:store(GeoList, Values, TrieIn);
		true ->
			OldValues = trie:fetch(GeoList, TrieIn),
			io:format("=>~p ~p~n",[OldValues, Values]),
			NewValues = lists:reverse(lists:umerge(lists:sort(OldValues),lists:sort(Values))),
			io:format("->~p~n",[NewValues]),
			trie:store(GeoList, NewValues, TrieIn)
	end.
