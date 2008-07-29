%%%-------------------------------------------------------------------
%%% File:      untitled.erl
%%% @author    Cliff Moon <> []
%%% @copyright 2008 Cliff Moon
%%% @doc  Membership process keeps track of dynomite node membership.  Maintains a version history.
%%%
%%% @end  
%%%
%%% @since 2008-03-30 by Cliff Moon
%%%-------------------------------------------------------------------
-module(membership).
-author('Cliff Moon').

-behaviour(gen_server).
-define(VIRTUALNODES, 100).

%% API
-export([start_link/1, join_node/2, nodes_for_key/1, nodes/0, state/0, state/1, old_partitions/0, partitions_for_node/2, fire_gossip/0, partition_for_key/1, stop/0, range/1]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-record(membership, {config, partitions, version, nodes, old_partitions}).

-include("config.hrl").

-define(power_2(N), (2 bsl (N-1))).

-ifdef(TEST).
-include("etest/membership_test.erl").
-endif.

%%====================================================================
%% API
%%====================================================================
%%--------------------------------------------------------------------
%% @spec start_link() -> {ok,Pid} | ignore | {error,Error}
%% @doc Starts the server
%% @end 
%%--------------------------------------------------------------------
start_link(Config) ->
  gen_server:start({local, membership}, ?MODULE, Config, []).

join_node(JoinTo, Me) ->
	gen_server:call({membership, JoinTo}, {join_node, Me}).
	
nodes_for_key(Key) ->
  gen_server:call(membership, {nodes_for_key, Key}).
  
nodes() ->
  gen_server:call(membership, nodes).
  
state() ->
  gen_server:call(membership, state).
  
state(State) ->
  gen_server:call(membership, {state, State}).
  
partitions_for_node(Node, Option) ->
  gen_server:call(membership, {partitions_for_node, Node, Option}).
  
partition_for_key(Key) ->
  gen_server:call(membership, {partition_for_key, Key}).

range(Partition) ->
  gen_server:call(membership, {range, Partition}).

old_partitions() ->
  gen_server:call(membership, old_partitions).

stop() ->
  gen_server:call(membership, stop).
	
fire_gossip() ->
  State = state(),
  Nodes = lists:filter(fun(E) -> E /= node() end, membership:nodes()),
  ModState = if
    length(Nodes) > 0 ->
      {Replies,BadNodes} = gen_server:multi_call(random_nodes(2, Nodes), membership, {share, State}),
      Merged = lists:foldl(
        fun({_,S}, empty) ->
          S;
        ({_,S}, M) -> 
          merge_states(M, S)
        end, empty, Replies);
    true -> State
  end,
  membership:state(ModState).

%%====================================================================
%% gen_server callbacks
%%====================================================================

%%--------------------------------------------------------------------
%% @spec init(Args) -> {ok, State} |
%%                         {ok, State, Timeout} |
%%                         ignore               |
%%                         {stop, Reason}
%% @doc Initiates the server
%% @end 
%%--------------------------------------------------------------------
init(Config) ->
  Nodes = erlang:nodes(),
	{ok, State} = if
		length(Nodes) > 0 -> 
		  Node = random_node(Nodes),
		  error_logger:info_msg("joining node ~p~n", [Node]),
		  join_node(Node, node());
		true -> {ok, create_initial_state(Config)}
	end,
  timer:apply_interval(500, membership, fire_gossip, []),
	{ok, State}.

%%--------------------------------------------------------------------
%% @spec 
%% handle_call(Request, From, State) -> {reply, Reply, State} |
%%                                      {reply, Reply, State, Timeout} |
%%                                      {noreply, State} |
%%                                      {noreply, State, Timeout} |
%%                                      {stop, Reason, Reply, State} |
%%                                      {stop, Reason, State}
%% @doc Handling call messages
%% @end 
%%--------------------------------------------------------------------

handle_call({join_node, Node}, _From, State) ->
  error_logger:info_msg("~p is joining the cluster.~n", [_From]),
  NewState = int_join_node(Node, State),
	{reply, {ok, NewState}, NewState};
	
handle_call({share, NewState}, _From, State) ->
  case vector_clock:compare(State#membership.version, NewState#membership.version) of
    less -> {reply, NewState, NewState};
    greater -> {reply, State, State};
    equal -> {reply, State, State};
    concurrent -> Merged = merge_states(State, NewState),
      {reply, Merged, Merged}
  end;
	
handle_call(nodes, _From, State = #membership{nodes=Nodes}) ->
  {reply, Nodes, State};
  
handle_call(state, _From, State) -> {reply, State, State};

handle_call({state, NewState}, _From, State) -> {reply, ok, NewState};
	
handle_call(old_partitions, _From, State = #membership{old_partitions=P}) when is_list(P) ->
  {reply, P, State};
  
handle_call(old_partitions, _From, State) -> {reply, [], State};
	
handle_call({range, Partition}, _From, State) ->
  {reply, int_range(Partition, State#membership.config), State};
	
handle_call({nodes_for_key, Key}, _From, State) ->
	{reply, int_nodes_for_key(Key, State), State};
	
handle_call({partitions_for_node, Node, Option}, _From, State) ->
  {reply, int_partitions_for_node(Node, State, Option), State};
  
handle_call({partition_for_key, Key}, _From, State) ->
  {reply, int_partition_for_key(Key, State), State};
	
handle_call(stop, _From, State) ->
  {stop, shutdown, ok, State}.

%%--------------------------------------------------------------------
%% @spec handle_cast(Msg, State) -> {noreply, State} |
%%                                      {noreply, State, Timeout} |
%%                                      {stop, Reason, State}
%% @doc Handling cast messages
%% @end 
%%--------------------------------------------------------------------
handle_cast(_, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                       {noreply, State, Timeout} |
%%                                       {stop, Reason, State}
%% @doc Handling all non call/cast messages
%% @end 
%%--------------------------------------------------------------------
handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @spec terminate(Reason, State) -> void()
%% @doc This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any necessary
%% cleaning up. When it returns, the gen_server terminates with Reason.
%% The return value is ignored.
%% @end 
%%--------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @doc Convert process state when code is changed
%% @end 
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%--------------------------------------------------------------------
%%% Internal functions
%%--------------------------------------------------------------------

int_range(Partition, #config{q=Q}) ->
  Size = partition_range(Q),
  {Partition, Partition+Size}.

random_node(Nodes) -> 
  [Node] = random_nodes(1, Nodes),
  Node.
  
random_nodes(N, Nodes) -> random_nodes(N, Nodes, []).
  
random_nodes(_, [], Taken) -> Taken;
  
random_nodes(0, _, Taken) -> Taken;
  
random_nodes(N, Nodes, Taken) ->
  {One, Two} = lists:split(random:uniform(length(Nodes)), Nodes),
  if
    length(Two) > 0 -> 
      [Head|Split] = Two,
      random_nodes(N-1, One ++ Split, [Head|Taken]);
    true ->
      [Head|Split] = One,
      random_nodes(N-1, Split, [Head|Taken])
  end.

%% partitions is a list starting with 0 which defines a partition space.
create_initial_state(Config) ->
  Q = Config#config.q,
  #membership{
    version=vector_clock:create(node()),
	  partitions=create_partitions(Q, node()),
	  config=Config,
	  nodes=[node()]}.
	
create_partitions(Q, Node) ->
  lists:map(fun(Partition) -> {Node, Partition} end, lists:seq(1, ?power_2(32), partition_range(Q))).
	
partition_range(Q) -> ?power_2(32-Q).

merge_states(StateA, StateB) ->
  PartA = StateA#membership.partitions,
  PartB = StateB#membership.partitions,
  Config = StateA#membership.config,
  Nodes = lists:merge(StateA#membership.nodes, StateB#membership.nodes),
  Partitions = merge_partitions(PartA, PartB, [], Config#config.n, Nodes),
  #membership{
    version=vector_clock:merge(StateA#membership.version, StateB#membership.version),
    nodes=Nodes,
    partitions=Partitions,
    config=Config
  }.
  
merge_partitions([], [], Result, _, _) -> lists:keysort(2, Result);
merge_partitions(A, [], Result, _, _) -> lists:keysort(2, A ++ Result);
merge_partitions([], B, Result, _, _) -> lists:keysort(2, B ++ Result);

merge_partitions([{NodeA,Number}|PartA], [{NodeB,Number}|PartB], Result, N, Nodes) ->
  if
    NodeA == NodeB -> 
      merge_partitions(PartA, PartB, [{NodeA,Number}|Result], N, Nodes);
    true ->
      case within(N, NodeA, NodeB, Nodes) of
        {true, First} -> merge_partitions(PartA, PartB, [{First,Number}|Result], N, Nodes);
        % bah, maybe we should just fucking pick one
        _ -> merge_partitions(PartA, PartB, [{NodeA,Number}|Result], N, Nodes)
      end
  end.

within(N, NodeA, NodeB, Nodes) ->
  within(N, NodeA, NodeB, Nodes, nil).

within(_, _, _, [], _) -> false;
  
within(N, NodeA, NodeB, [Head|Nodes], nil) ->
  case Head of
    NodeA -> within(N-1, NodeB, nil, Nodes, NodeA);
    NodeB -> within(N-1, NodeA, nil, Nodes, NodeB);
    _ -> within(N-1, NodeA, NodeB, Nodes, nil)
  end;
  
within(0, _, _, _, _) -> false;
  
within(N, Last, nil, [Head|Nodes], First) ->
  case Head of
    Last -> {true, First};
    _ -> within(N-1, Last, nil, Nodes, First)
  end.

int_join_node(NewNode, #membership{config=Config,partitions=Partitions,version=Version,nodes=OldNodes}) ->
  Nodes = lists:sort([NewNode|OldNodes]),
  Tokens = ?power_2(Config#config.q) div length(Nodes),
  FromEachNode = Tokens div (length(Nodes)-1),
  {CleanNodes,_} = lists:partition(fun(E) -> E =/= NewNode end, Nodes),
  P = steal_partitions(NewNode, Tokens, FromEachNode, FromEachNode, CleanNodes, Partitions, []),
  #membership{config=Config,
    partitions = P,
    version = vector_clock:increment(node(), Version),
    nodes=Nodes,
    old_partitions=Partitions}.
  
steal_partitions(_, 0, _, _, _, Partitions, Stolen) ->
  lists:keysort(2, Partitions ++ Stolen);
  
steal_partitions(Node, Tokens, 0, FromEach, [Head|Nodes], Partitions, Stolen) ->
  if
    length(Nodes) > 0 -> steal_partitions(Node, Tokens, FromEach, FromEach, Nodes, Partitions, Stolen);
    true -> steal_partitions(Node, Tokens, FromEach, FromEach, [Head|Nodes], Partitions, Stolen)
  end;
  
steal_partitions(Node, Tokens, FromThis, FromEach, [Head|Nodes], Partitions, Stolen) ->
  case lists:keytake(Head, 1, Partitions) of
    {value, {Head, Partition}, NewPartitions} ->
      steal_partitions(Node, Tokens-1, FromThis-1, FromEach, [Head|Nodes], NewPartitions, [{Node,Partition}|Stolen]);
    % there may be another node joining the system in this case.  we should handle gracefully
    false -> steal_partitions(Node, Tokens, FromThis, FromEach, [Head|Nodes], Partitions, Stolen)
  end.
  
int_partitions_for_node(Node, State, master) ->
  Partitions = State#membership.partitions,
  {Matching,_} = lists:partition(fun({N,_}) -> N == Node end, Partitions),
  lists:map(fun({_,P}) -> P end, Matching);
  
int_partitions_for_node(Node, State, all) ->
  Config = State#membership.config,
  Partitions = State#membership.partitions,
  Nodes = n_nodes(Node, Config#config.n, lists:reverse(State#membership.nodes)),
  lists:foldl(fun(E, Acc) -> 
      lists:merge(Acc, int_partitions_for_node(E, State, master)) 
    end, [], Nodes).
  
int_nodes_for_key(Key, State) ->
  error_logger:info_msg("inside int_nodes_for_key~n", []),
  KeyHash = lib_misc:hash(Key),
  Config = State#membership.config,
  Q = Config#config.q,
  Partition = find_partition(KeyHash, Q),
  error_logger:info_msg("found partition ~w for key ~p~n", [Partition, Key]),
  int_nodes_for_partition(Partition, State).
  
int_nodes_for_partition(Partition, State) ->
  Config = State#membership.config,
  Partitions = State#membership.partitions,
  Q = Config#config.q,
  N = Config#config.n,
  {Node,Partition} = lists:nth(index_for_partition(Partition, Q), Partitions),
  error_logger:info_msg("Node ~w Partition ~w N ~w~n", [Node, Partition, N]),
  n_nodes(Node, N, State#membership.nodes).
  
int_partition_for_key(Key, State) ->
  KeyHash = lib_misc:hash(Key),
  Config = State#membership.config,
  Q = Config#config.q,
  find_partition(KeyHash, Q).
  
find_partition(Hash, Q) ->
  Size = partition_range(Q),
  Factor = (Hash div Size),
  Rem = (Hash rem Size),
  if
    Rem > 0 -> Factor * Size + 1;
    true -> ((Factor-1) * Size) + 1
  end.
  
%1 based index, thx erlang
index_for_partition(Partition, Q) ->
  Size = partition_range(Q),
  Index = (Partition div Size) + 1.
  
n_nodes(StartNode, N, Nodes) ->
  if
    N >= length(Nodes) -> Nodes;
    true -> n_nodes(StartNode, N, Nodes, [], Nodes)
  end.
  
n_nodes(_, 0, _, Taken, _) -> lists:reverse(Taken);

n_nodes(StartNode, N, [], Taken, Cycle) -> n_nodes(StartNode, N, Cycle, Taken, Cycle);

n_nodes(found, N, [Head|Nodes], Taken, Cycle) ->
  n_nodes(found, N-1, Nodes, [Head|Taken], Cycle);
  
n_nodes(StartNode, N, [StartNode|Nodes], Taken, Cycle) ->
  n_nodes(found, N-1, Nodes, [StartNode|Taken], Cycle);
  
n_nodes(StartNode, N, [_|Nodes], Taken, Cycle) ->
  n_nodes(StartNode, N, Nodes, Taken, Cycle).
  