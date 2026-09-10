class Simulation {
  constructor() {
    this.subs = {};
    this.inboxMap = {};
    this.retained = {};
  }

  subscribe(topic, client) {
    const clients = Object.prototype.hasOwnProperty.call(this.subs, topic)
      ? this.subs[topic]
      : (this.subs[topic] = []);
    if (clients.includes(client)) return "false";
    clients.push(client);
    if (Object.prototype.hasOwnProperty.call(this.retained, topic)) {
      if (!Object.prototype.hasOwnProperty.call(this.inboxMap, client)) {
        this.inboxMap[client] = [];
      }
      this.inboxMap[client].push(`${topic}:${this.retained[topic]}`);
    }
    return "true";
  }

  unsubscribe(topic, client) {
    if (!Object.prototype.hasOwnProperty.call(this.subs, topic)) return "false";
    const clients = this.subs[topic];
    const idx = clients.indexOf(client);
    if (idx < 0) return "false";
    clients.splice(idx, 1);
    if (clients.length === 0) delete this.subs[topic];
    return "true";
  }

  publish(topic, message) {
    const clients = Object.prototype.hasOwnProperty.call(this.subs, topic)
      ? this.subs[topic]
      : [];
    const payload = `${topic}:${message}`;
    for (const client of clients) {
      if (!Object.prototype.hasOwnProperty.call(this.inboxMap, client)) {
        this.inboxMap[client] = [];
      }
      this.inboxMap[client].push(payload);
    }
    return String(clients.length);
  }

  inbox(client) {
    const items = Object.prototype.hasOwnProperty.call(this.inboxMap, client)
      ? this.inboxMap[client]
      : [];
    return items.join(", ");
  }

  listTopics() {
    return Object.keys(this.subs).sort().join(", ");
  }

  subscribers(topic) {
    const clients = Object.prototype.hasOwnProperty.call(this.subs, topic)
      ? this.subs[topic].slice()
      : [];
    return clients.sort().join(", ");
  }

  peek(client) {
    const items = Object.prototype.hasOwnProperty.call(this.inboxMap, client)
      ? this.inboxMap[client]
      : [];
    return items.length ? items[0] : "";
  }

  ack(client, n) {
    if (n <= 0 || !Object.prototype.hasOwnProperty.call(this.inboxMap, client)) {
      return "invalid_request";
    }
    const items = this.inboxMap[client];
    if (n > items.length) return "invalid_request";
    items.splice(0, n);
    return String(items.length);
  }

  retain(topic, message) {
    this.retained[topic] = message;
    return "";
  }
}

module.exports = { Simulation };
