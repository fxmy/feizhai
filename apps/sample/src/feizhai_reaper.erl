%% FEIZHAI REAPER
%% sole job is to keep track & delete outdated feizhais
%% depends on the ordering guantee of kvs chain ops

%% kvs:traversal(feizhai,<<"rYuGLPlp9wI02w">>,2,#iterator.next).
%% the only problem now is to find the last id(bottom in the chain)
%% 1) kvs:traversal to go through top to bottom when app starts
%%	pros: public api
%%	cons: inefficient
%% 2) keep a seperate bottom record
%%	pros: efficient, easy to use
%%	cons: need *solid logic* to guard seperate bottom record

%% use wf message bus & gen_server timeout to track & auto-expire feizhai
-module(feizhai_reaper).

-behaviour(gen_server).

-include_lib("kvs/include/metainfo.hrl").
-include_lib("sample/include/feizhai.hrl").

%% API
-export([start_link/0, metainfo/0]).

%% gen_server callbacks
-export([init/1,
%         handle_call/3,
%         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).

-compile([export_all]).

-record(state, {feizhai_id, triggerT}).
-record(feizhai_target, {id, feizhai_token, last_active}).

%%%===================================================================
%%% API
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
	wf:reg(channel_reap),
	case kvs:get(feizhai_target, 1) of
		{ok, #feizhai_target{id=1, feizhai_token=FZtoken, last_active=LAdatetime}} ->
			%% started from a prior state (feizhai table not empty, eg app rebooted
			%%
			%% assert last_active consistency
			{ok,#feizhai{id=FZtoken,
				     public_token=FZtoken,
				     last_active=LAdatetime,
				     prev=undefined}} = kvs:get(feizhai,FZtoken),
			Now = calendar:datetime_to_gregorian_seconds( calendar:universal_time()),
			Future = calendar:datetime_to_gregorian_seconds(LAdatetime) + wf:config(sample, feizhai_life, 5*60),
			case (Delta=Future-Now)>0 of
				true -> %not yet
					wf:info(?MODULE,"not yet~n",[]),
					{ok, #state{feizhai_id=FZtoken,triggerT=Future}, Delta*1000};
				false -> %maybe more than one feizhai need to be reapped
					wf:info(?MODULE,"maybe more than one feizhai need to be reapped~n",[]),
					{LastIdAlive, LAliveDT, DeadFZs} =
					decayed_feizhai_ids(FZtoken, Now - wf:config(sample, feizhai_life, 5*60)),
					%clean up already dead ones
					[kvs:remove(feizhai, Id) || Id <- DeadFZs],
					{Timeout,TrigT} = calc_init_timeout(LastIdAlive, LAliveDT,
									    wf:config(sample, feizhai_life, 5*60),
									    Now),
					%update feizhai_target
					update_fz_target(LastIdAlive, LAliveDT),
					{ok, #state{feizhai_id=LastIdAlive,triggerT=TrigT}, Timeout}
			end;
		{error, not_found} ->
			%% feizhai table all empty
			wf:info(?MODULE,"feizhai table empty when initing~n",[]),
			{ok, #state{}, hibernate}
	end.

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
%handle_call(_Request, _From, State) ->
%    Reply = ok,
%    {reply, Reply, State}.

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
%handle_cast(_Msg, State) ->
%    {noreply, State}.

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
handle_info(_Info, State) ->
	wf:info(?MODULE, "~p got info ~p", [self(), _Info]),
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
				  #table{name=feizhai_target, fields=record_info(fields, feizhai_target)}
				 ]}.

%% search for outdated feizhai starting from bottom up in the KVS-Chain
decayed_feizhai_ids(IdLast, GregrSec) when is_integer(GregrSec) ->
	DateTime = calendar:gregorian_seconds_to_datetime(GregrSec),
	{OldestId, LA, Decayed} = decayed_feizhai_ids(IdLast, DateTime, []),
	{OldestId, LA, lists:reverse(Decayed)}.

decayed_feizhai_ids(IdLast, DateTime, Acc) ->
	{ok, #feizhai{id=IdLast,public_token=IdLast,last_active=LA,next=NextId}} = kvs:get(feizhai, IdLast),
	case LA > DateTime of
		true ->
			{IdLast,LA,Acc};
		false ->
			case NextId of
				undefined ->
					{undefined,hibernate,[IdLast|Acc]};
				_Other ->
					decayed_feizhai_ids(NextId, DateTime, [IdLast|Acc])
			end
	end.

update_fz_target(undefined, hibernate) ->
	kvs:delete(feizhai_target, 1);
update_fz_target(FZtoken, LastActive) ->
	kvs:put(#feizhai_target{id=1,feizhai_token=FZtoken,last_active=LastActive}).

-spec calc_init_timeout(undefined|binary(),hibernate|calendar:datetime(),integer(),integer()) ->
	{hibernate|integer(), undefined|calendar:datetime()}.
calc_init_timeout(undefined, hibernate, _DefaultSec, _NowSec) ->
	{hibernate, undefined};
calc_init_timeout(_LastIdAlive, LAliveDT, DefaultSec, NowSec) ->
	TriggerTSec = calendar:datetime_to_gregorian_seconds(LAliveDT)+DefaultSec,
	Timeout=1000*(TriggerTSec-NowSec),
	{Timeout, calendar:gregorian_seconds_to_datetime(TriggerTSec)}.
