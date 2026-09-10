function obj = Simulation()
  subs = containers.Map();
  inbox_map = containers.Map();
  retained = containers.Map();

  obj.subscribe = @subscribe;
  obj.unsubscribe = @unsubscribe;
  obj.publish = @publish;
  obj.inbox = @inbox;
  obj.list_topics = @list_topics;
  obj.subscribers = @subscribers;
  obj.peek = @peek;
  obj.ack = @ack;
  obj.retain = @retain;

  function result = subscribe(topic, client)
    if (!subs.isKey(topic))
      subs(topic) = {};
    endif
    clients = subs(topic);
    for i = 1:numel(clients)
      if (strcmp(clients{i}, client))
        result = "false";
        return;
      endif
    endfor
    clients{end + 1} = client;
    subs(topic) = clients;
    if (retained.isKey(topic))
      if (!inbox_map.isKey(client))
        inbox_map(client) = {};
      endif
      items = inbox_map(client);
      items{end + 1} = sprintf("%s:%s", topic, retained(topic));
      inbox_map(client) = items;
    endif
    result = "true";
  endfunction

  function result = unsubscribe(topic, client)
    if (!subs.isKey(topic))
      result = "false";
      return;
    endif
    clients = subs(topic);
    idx = 0;
    for i = 1:numel(clients)
      if (strcmp(clients{i}, client))
        idx = i;
        break;
      endif
    endfor
    if (idx == 0)
      result = "false";
      return;
    endif
    clients(idx) = [];
    if (isempty(clients))
      remove(subs, topic);
    else
      subs(topic) = clients;
    endif
    result = "true";
  endfunction

  function result = publish(topic, message)
    if (subs.isKey(topic))
      clients = subs(topic);
    else
      clients = {};
    endif
    payload = sprintf("%s:%s", topic, message);
    for i = 1:numel(clients)
      client = clients{i};
      if (!inbox_map.isKey(client))
        inbox_map(client) = {};
      endif
      items = inbox_map(client);
      items{end + 1} = payload;
      inbox_map(client) = items;
    endfor
    result = sprintf("%d", numel(clients));
  endfunction

  function result = inbox(client)
    if (!inbox_map.isKey(client))
      result = "";
      return;
    endif
    items = inbox_map(client);
    if (isempty(items))
      result = "";
      return;
    endif
    result = strjoin(items, ", ");
  endfunction

  function result = list_topics()
    topics = subs.keys();
    if (isempty(topics))
      result = "";
      return;
    endif
    topics = sort(topics);
    result = strjoin(topics, ", ");
  endfunction

  function result = subscribers(topic)
    if (!subs.isKey(topic))
      result = "";
      return;
    endif
    clients = sort(subs(topic));
    if (isempty(clients))
      result = "";
      return;
    endif
    result = strjoin(clients, ", ");
  endfunction

  function result = peek(client)
    if (!inbox_map.isKey(client))
      result = "";
      return;
    endif
    items = inbox_map(client);
    if (isempty(items))
      result = "";
      return;
    endif
    result = items{1};
  endfunction

  function result = ack(client, n)
    if (n <= 0 || !inbox_map.isKey(client))
      result = "invalid_request";
      return;
    endif
    items = inbox_map(client);
    if (n > numel(items))
      result = "invalid_request";
      return;
    endif
    items(1:n) = [];
    inbox_map(client) = items;
    result = sprintf("%d", numel(items));
  endfunction

  function result = retain(topic, message)
    retained(topic) = message;
    result = "";
  endfunction
endfunction
