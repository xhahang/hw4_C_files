-module(hw4).

% functions for HW4, Q3: Hypercube Congestion
-export([all_nodes/1, congestion_0/1, congestion/1, link_counts/1, msg_count/3, 
		route1/3, traffic/1, transpose/1]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                              %
%  Functions for HW4 Q3: Hypercube Congestion                                  %
%                                                                              %
% The functions in this module demonstrate a traffic pattern that creates      %
% congestion on a hypercube when using dimension routing.  First, some         %
% definitions:                                                                 %
%   Dimension: the dimension of the hypercube.  We will use D to denote the    %
%     dimension of the hypercube.                                              %
%   Node address: a list of length Dim where every element is a 0 or 1.        %
%     We use little-endian order.  The first element of a node address         %
%     is the least-significant bit of the address.  Say that the least         %
%     significant bit of an address is bit 0.  Sadly, Erlang uses 1-based      %
%     indexing; so, bit-K of an address is list:nth(K+1, Address).             % 
%   Traffic Pattern: a list of {Src, Dst} pairs where Src and Dst are          %
%     node addresses.  This means a message is sent from node Src to           %
%     node Dst.                                                                %
%                                                                              %
% Congestion:                                                                  %
%   We are interested in traffic patterns where every Src is distinct, i.e.    %
%   each node sends at most one message, and there are no two source nodes     %
%   that send messages to the same destination.  Note that such a traffic      %
%   pattern could be routed in a single step using a cross-bar network.        %
%     Congestion occurs if two messages need to traverse the same link.        %
%   This means that if each node tries to send a new message to its            %
%   destination on each time step, then, the throughput of the network         %
%   will be constrained by the most congested link.  For example, if           %
%   there is a link that conveys C messages each time the traffic pattern      %
%   is sent, then we can send the traffic pattern at most once every           %
%   time steps.                                                                %
%																			   %
% The homework asks you to show that the 'transpose' pattern for a hypercube   %
% with 2^D nodes has some links that convey a*2^(D/2) messages each            %
% time the traffic pattern is sent.  The code in this module lets you          % 
% experimentally test this claim.  In particular, the function                 %
%   congestion_0(D) -> {MaxCongestion, CongestedLinks}                         %
% where MaxCongestion is the maximum number of messages conveyed by any link   %
% when routing the transpose pattern, and CongestedLinks is the number of      %
% links with this level of congestion.                                         % 
%                                                                              %
%   As implemented, congestion_0(Dim) is embarrassingly slow.  Let N = 2^D be  %
% the number of nodes in a D-dimensional hypercube.  congestion_0 runs in time %
% D^2*N^2, which is embarrassingly slow -- but it kept the code simple.        %
% I've also provided the code for congestion(Dim) which runs in time D^2*N;
% this may be useful to you if you want to run experiments with larger D.
%                                                                              %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% route1(Src, Dst, K) -> {Before, After}
%   Perform a single step in dimenstion routing on a hypercube.
%   Parameters:
%     Src, Dst, Before, and After are node addresses for a D-dimensional hypercube.
%       Node addresses are represented by lists of D elements where each element is a 0 or 1.
%       D is implicit in our parameters:  D = length(Src), and we require length(Dst) = length(Src).
%     K specifies which step of dimension routing to model.
%       When K=0, we route according to the least significant bit of Dst,
%       i.e. the first element of the list.
%       More generally, We route according to the K^th bit of Dst (zero based indexing).
%   Return value: {Before, After}
%     Before is the node that the message being sent from Src to Dst is at
%       before routing along dimension K.
%     After is the node that the message being sent from Src to Dst is at
%       after routing along dimension K.
route1(Src, Dst, K)
    when is_list(Src), is_list(Dst), length(Src) == length(Dst),
	 is_integer(K), 0 =< K, K < length(Src) ->
  D = length(Src),
  Before = lists:sublist(Dst, K) ++ lists:sublist(Src, K+1, D-K),
  After  = lists:sublist(Dst, K+1) ++ lists:sublist(Src, K+2, D-(K+1)),
  { Before, After }.


% msg_count(Node, Link, SrcDstList) -> Count
%   Parameters:
%     Node: address of a router node, a list.  Let D = length(Node)
%     Link: one of the D links out of Node.
%     SrcDstList: a list of {Src, Dst} pairs,
%       where Src and Dst are node addresses, i.e. lists of length D of 0s and 1s.
%   Return value: Count
%     How many messages are sent from Node along Link when
%     sending messages from each Src to the corresponding Dst.
msg_count(Node, Link, [{Src, Dst} | Tl]) ->
  {Before, After} = route1(Src, Dst, Link),
  case (Before == Node) andalso (Before /= After) of
    true -> 1;
    false -> 0
  end + msg_count(Node, Link, Tl);
msg_count(_, _, []) -> 0.


% all_nodes(D) -> ListOfNodeAddresses
%   Return a list the node addresses for all nodes of a D-dimensional hypercube.
all_nodes(D) when is_integer(D), D > 0 ->
  A = all_nodes(D-1),
  [[0 | X] || X <- A] ++ [[1 | X] || X <- A];
all_nodes(0) -> [[]].

% transpose(Addr)
%   Swap the left and right halves of an address.
%   Let Addr be a node address for a D-dimensional hypercube.
%   For simplicity, assume D is even, and let Left and Right be lists of length
%   D div 2 such that Left ++ Right == Addr.
%   Return the node address Right ++ Left.
transpose(Addr) when is_list(Addr) ->
  {A, B} = lists:split(length(Addr) div 2, Addr),
  B ++ A.

% traffic(D) -> SrcDstList
%   Return the SrcDstList for a D-dimensional hypercube where each node sends
%   a message to its transpose.
traffic(D) when is_integer(D), 0 =< D ->
  Nodes = all_nodes(D),
  lists:zip(Nodes, [transpose(Node) || Node <- Nodes]).

% congestion_0(D) -> {MaxCongestion, MaxCongestedLinks}.
%   Let SrcDstList be the traffic pattern consisting of all pairs {Src, Dst},  %
%     where Src is the address of a D-dimensional hypercube and Dst is the     %
%     transpose of Src.                                                        %
%   Return {MaxCongestion, MaxCongestedLinks} where                            %
%     MaxCongestion is the maximum congestion of a link, i.e. the maximum      %
%       number of messages sent over a particular link when routing            %
%       SrcDstList.                                                            %
%     MaxCongestedLinks is the number of links over which MaxCongestion        %
%       messages are sent when routing SrcDstList.                             %
%                                                                              %
% Remarks on runtime for congestion_0:                                         %
%   Let N = 2^D be the number of nodes in a D-dimensional hypercube.  The      %
%   router for each node has D links to other nodes.  Thus there are N*D       %
%   links.  The transpose traffic pattern has one {Src, Dst} pair for each     %
%   of the N nodes.  congestion_0 checks for each link, whether or not each    %
%   message in the traffic pattern uses this link.  Thus it makes (N*D)*N      %
%   calls to route1 -- route1 simulates one step of dimension routing.         %
%   route1 runs in Theta(D) time.  Thus the total time is D^2 N^2.             %
congestion_0(D) ->
  Nodes = all_nodes(D),
  SrcDstList = traffic(D),
  V = [    msg_count(Node, Link, SrcDstList)
	|| Node <- Nodes, Link <- lists:seq(0, D-1) ],
  MaxCount = lists:max(V),
  { MaxCount, length([ok || Count <- V, Count == MaxCount])}.

% congestion(D) -> {MaxCongestion, MaxCongestedLinks}.
%   congestion(D) computes the same result as congestion_0(D) as described     %
%   above, but it is faster.  congestion(D) calls link_counts(SrcDstList)      %
%   which you need to write.  If link_counts(SrcDstList) is implemented as     %
%   intended, then congestion should run in time O(D^2 N).  As noted in the    %
%   comments for this module, we could get time O(D N) if we used Erlang       %
%   integers to represent node addresses and replaced the list operations      %
%   in route1/3 with bit-wise logical operations and shifts.  But, this        %
%   is "fast enough" and we won't add the extra design issue of doing bit      %
%   fiddling.                    
% (Don't forget that the N in the runtime is still exponential in D, so don't
% try this for huge values of D :). I can do this with D=20 on my laptop but
% it takes a while.)
congestion(D) ->
  SrcDstList = traffic(D),
  V = maps:values(link_counts(SrcDstList)),
  MaxCount = lists:max(V),
  { MaxCount, length([ok || Count <- V, Count == MaxCount]) }.


% link_counts(SrcDstList) -> CountMap                                          %
%   Count the number of messages sent over each link of a hypercube when       %
%   routing the messages of SrcDstList.                                        %
%   Parameters:                                                                %
%     SrcDstList: a list of {Src, Dst} pairs where Src and Dst are node        %
%       addresses.  The dimension of the hypercube, D, is length(Src)          %
%       and we assume length(Dst) = length(Src).                               %
%   Return value:                                                              %
%     CountMap: an Erlang map.                                                 %
%       See https://www.erlang.org/doc/apps/stdlib/maps.html                   %
%       Keys for the map are {NodeAddress, K} tuples where                     %
%         NodeAddress is the address of the node for the router.               %
%         K is which dimension this is routing.  0 =< Link < D.                %
%     For each link {NodeAddress, K} used in routing the messages of           %
%     SrcDstList, maps:get({NodeAddress, K}, CountMap) returns the number      %
%     of messages that were sent over this link when routing the messages      %
%     of SrcDstList.  If no messages were sent, then CountMap may either       %
%     have no entry for that link, or the entry can be 0.                      %
link_counts(SrcDstList) ->
  count_them(SrcDstList, #{}).

count_them([{Src,Dst} | Tl], CountMap) ->
  count_them(Tl, count_them(Src, Dst, 0, CountMap));
count_them([], CountMap) -> CountMap.

% This solution has an extra factor of D (i.e. length(Src)) runtime
%   because it seemed easier to build the current node address by splitting
%   Src and Dst and concatenating the prefix of Dst with the suffix of Src.
%   I don't expect to run this with D large enough for this to be an issue.
count_them(Src, Dst, K, CountMap) when K < length(Src) ->
  count_them(Src, Dst, K+1,
    case lists:nth(K+1, Src) == lists:nth(K+1, Dst) of
      true -> CountMap;
      false ->
	{_, S_post} = lists:split(K, Src),
	{D_pre, _} = lists:split(K, Dst),
	Node = D_pre ++ S_post,
        CountMap#{{Node, K} => maps:get({Node, K}, CountMap, 0) + 1}
    end);
count_them(_, _, _, CountMap) -> CountMap.