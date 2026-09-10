class Simulation {
  constructor() {}
  subscribe(topic, client) { throw new Error('not implemented'); }
  unsubscribe(topic, client) { throw new Error('not implemented'); }
  publish(topic, message) { throw new Error('not implemented'); }
  inbox(client) { throw new Error('not implemented'); }
  listTopics() { throw new Error('not implemented'); }
  subscribers(topic) { throw new Error('not implemented'); }
  peek(client) { throw new Error('not implemented'); }
  ack(client, n) { throw new Error('not implemented'); }
  retain(topic, message) { throw new Error('not implemented'); }
}
module.exports = { Simulation };
