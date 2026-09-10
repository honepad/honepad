// subscribe(topic, client)
// unsubscribe(topic, client)
// publish(topic, message)
// inbox(client)
// list_topics()
// subscribers(topic)
// peek(client)
// ack(client, n)
// retain(topic, message)
pub struct Simulation;

impl Simulation {
    pub fn new() -> Self {
        Self
    }
}
