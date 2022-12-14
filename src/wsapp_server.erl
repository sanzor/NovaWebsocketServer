-module(wsapp_server).
-behaviour(gen_server).

-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2]).

-export([
         start_link/0,
         publish/2,
         online/2,
         offline/2,
         subscribe/2,
         get_messages/1]).

-define(SERVER,?MODULE).

-record(state,{

}).
%----------------------------API ----------------------------------%
-spec get_messages(Topic::string())->{ok,Messages::list()} | error .
get_messages(Topic)->
    gen_server:call(?MODULE,{get_messages,Topic}).

-spec publish(Topic::string(),Message::any())->ok.
publish(Topic,Message)->
    gen_server:cast(?MODULE, {publish,{Topic,Message}}).


-spec online(User::string(),Socket::pid())->ok.
online(User,Socket)->
    gen_server:call(?MODULE, {online,{User,Socket}}).



-spec offline(User::string(),Socket::pid())->ok.
offline(User,Socket)->
    gen_server:call(?MODULE, {offline,{User,Socket}}).

-spec subscribe(User::string(),Topic::string())->ok.
subscribe(User,Topic)->
    gen_server:call(?MODULE, {subscribe,{User,Topic}}).


-spec unsubscribe(User::string(),Topic::string())->ok.
unsubscribe(User,Topic)->
    gen_server:call(?MODULE, {unsubscribe,{User, Topic}}).


start_link()->
    gen_server:start_link({local,?SERVER}, ?MODULE, [], []).



%-------------callbacks---------------------------------------%

init(Args)->
    process_flag(trap_exit,true),
    self() ! start,
    {ok,#state{}}.

%% @doc 
%% Handling call messages
%% @end

handle_call({get_messages,Topic},_,State)->
    Messages=ets:match(messages, {Topic,'$1'}),
    {reply,{ok,Messages},State};
handle_call({subscribe,{Topic,User}},_,State)->
    true=ets:insert(subsribers, {Topic,User}),
    {reply,ok,State};
handle_call({unsubscribe,{Topic,User}},_,State)->
    case ets:match_object(subscribers, {Topic,User}) of
        [{Topic,User}] -> 
            ets:delete_object(subscribers,{Topic,User}),
            {reply,ok,State};
        [] ->
            logger:info("Nothing to unsubscribe user:~p topic:~p~n",[User,Topic]),
            {reply,ok,State}
    end;
handle_call({online,{User,Socket}},_,State)->
    true=ets:insert(online,{User,Socket}),
    {reply,ok,State};
handle_call({offline,{User,Socket}},_,State)->
    ets:delete_object(online,{User,Socket}),
    {reply,ok,State}.



%% @doc 
%% 
%% Handling cast messages
%% @end
handle_cast({publish,{Topic,Message}},State)->
    Subscribers=ets:match(subscribers,{Topic,'$1'}),
    [[send(Socket,Message)|| [Socket]<-online_sockets(Subscriber)] || [Subscriber]<-Subscribers ],
    {noreply,State}.


%% @doc 
%% Handling info messages
%% @end
handle_info(start,State)->
    ets:new(subscribers,[named_table,bag]),
    ets:new(online,[named_table,bag]),
    ets:new(messages,[named_table,bag]),
    {noreply,State};

handle_info(Message,State)->
    {reply,Message,State}.

terminate(_Reason,_State)->ok.
send(Socket,Message)->
    Socket ! Message.
online_sockets(User)->
    Sockets=ets:match(online, {User,'$1'}),
    Sockets.
