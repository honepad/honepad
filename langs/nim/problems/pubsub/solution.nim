import std/[tables, algorithm, strutils, sequtils]

type
  Simulation = ref object
    subs: Table[string, seq[string]]
    inboxMap: Table[string, seq[string]]
    retained: Table[string, string]

proc subscribe(self: Simulation; topic, client: string): string =
  if topic in self.subs and client in self.subs[topic]:
    return "false"
  self.subs.mgetOrPut(topic, @[]).add(client)
  if topic in self.retained:
    self.inboxMap.mgetOrPut(client, @[]).add(topic & ":" & self.retained[topic])
  result = "true"

proc unsubscribe(self: Simulation; topic, client: string): string =
  if topic notin self.subs or client notin self.subs[topic]:
    return "false"
  self.subs[topic] = self.subs[topic].filterIt(it != client)
  if self.subs[topic].len == 0:
    self.subs.del(topic)
  result = "true"

proc publish(self: Simulation; topic, message: string): string =
  if topic notin self.subs:
    return "0"
  let payload = topic & ":" & message
  for client in self.subs[topic]:
    self.inboxMap.mgetOrPut(client, @[]).add(payload)
  result = $self.subs[topic].len

proc inbox(self: Simulation; client: string): string =
  if client notin self.inboxMap:
    return ""
  result = self.inboxMap[client].join(", ")

proc listTopics(self: Simulation): string =
  var topics = toSeq(self.subs.keys)
  topics.sort()
  result = topics.join(", ")

proc subscribers(self: Simulation; topic: string): string =
  if topic notin self.subs:
    return ""
  var clients = self.subs[topic]
  clients.sort()
  result = clients.join(", ")

proc peek(self: Simulation; client: string): string =
  if client notin self.inboxMap or self.inboxMap[client].len == 0:
    return ""
  result = self.inboxMap[client][0]

proc ack(self: Simulation; client: string; n: int64): string =
  if n <= 0 or client notin self.inboxMap:
    return "invalid_request"
  if n > self.inboxMap[client].len:
    return "invalid_request"
  self.inboxMap[client] = self.inboxMap[client][n .. ^1]
  result = $self.inboxMap[client].len

proc retain(self: Simulation; topic, message: string): string =
  self.retained[topic] = message
  result = ""
