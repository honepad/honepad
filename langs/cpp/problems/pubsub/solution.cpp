#ifndef HONEPAD_SOLUTION_INCLUDED
#define HONEPAD_SOLUTION_INCLUDED

#include "harness.hpp"

#include <algorithm>
#include <map>
#include <string>
#include <vector>

class Simulation : public Harness {
  std::map<std::string, std::vector<std::string>> subs;
  std::map<std::string, std::vector<std::string>> inbox_map;
  std::map<std::string, std::string> retained;

  std::string subscribe(const std::string& topic, const std::string& client) {
    auto& clients = subs[topic];
    if (std::find(clients.begin(), clients.end(), client) != clients.end()) {
      return "false";
    }
    clients.push_back(client);
    auto it = retained.find(topic);
    if (it != retained.end()) {
      inbox_map[client].push_back(topic + ":" + it->second);
    }
    return "true";
  }

  std::string unsubscribe(const std::string& topic, const std::string& client) {
    auto it = subs.find(topic);
    if (it == subs.end()) {
      return "false";
    }
    auto& clients = it->second;
    auto pos = std::find(clients.begin(), clients.end(), client);
    if (pos == clients.end()) {
      return "false";
    }
    clients.erase(pos);
    if (clients.empty()) {
      subs.erase(it);
    }
    return "true";
  }

  std::string publish(const std::string& topic, const std::string& message) {
    auto it = subs.find(topic);
    if (it == subs.end()) {
      return "0";
    }
    std::string payload = topic + ":" + message;
    for (const auto& client : it->second) {
      inbox_map[client].push_back(payload);
    }
    return std::to_string(it->second.size());
  }

  std::string inbox(const std::string& client) const {
    auto it = inbox_map.find(client);
    if (it == inbox_map.end()) {
      return "";
    }
    std::string out;
    for (size_t i = 0; i < it->second.size(); i++) {
      if (i > 0) {
        out += ", ";
      }
      out += it->second[i];
    }
    return out;
  }

  std::string list_topics() const {
    std::vector<std::string> topics;
    for (const auto& entry : subs) {
      topics.push_back(entry.first);
    }
    std::sort(topics.begin(), topics.end());
    std::string out;
    for (size_t i = 0; i < topics.size(); i++) {
      if (i > 0) {
        out += ", ";
      }
      out += topics[i];
    }
    return out;
  }

  std::string subscribers(const std::string& topic) const {
    auto it = subs.find(topic);
    if (it == subs.end()) {
      return "";
    }
    std::vector<std::string> clients = it->second;
    std::sort(clients.begin(), clients.end());
    std::string out;
    for (size_t i = 0; i < clients.size(); i++) {
      if (i > 0) {
        out += ", ";
      }
      out += clients[i];
    }
    return out;
  }

  std::string peek(const std::string& client) const {
    auto it = inbox_map.find(client);
    if (it == inbox_map.end() || it->second.empty()) {
      return "";
    }
    return it->second.front();
  }

  std::string ack(const std::string& client, int64_t n) {
    auto it = inbox_map.find(client);
    if (n <= 0 || it == inbox_map.end()) {
      return "invalid_request";
    }
    if (n > static_cast<int64_t>(it->second.size())) {
      return "invalid_request";
    }
    it->second.erase(it->second.begin(), it->second.begin() + static_cast<size_t>(n));
    return std::to_string(it->second.size());
  }

  std::string retain(const std::string& topic, const std::string& message) {
    retained[topic] = message;
    return "";
  }

 public:
  JsonVal call(const std::string& method, const std::vector<JsonVal>& args) override {
    std::string text;
    if (method == "subscribe") {
      text = subscribe(arg_str(args, 0), arg_str(args, 1));
    } else if (method == "unsubscribe") {
      text = unsubscribe(arg_str(args, 0), arg_str(args, 1));
    } else if (method == "publish") {
      text = publish(arg_str(args, 0), arg_str(args, 1));
    } else if (method == "inbox") {
      text = inbox(arg_str(args, 0));
    } else if (method == "listTopics") {
      text = list_topics();
    } else if (method == "subscribers") {
      text = subscribers(arg_str(args, 0));
    } else if (method == "peek") {
      text = peek(arg_str(args, 0));
    } else if (method == "ack") {
      text = ack(arg_str(args, 0), arg_i64(args, 1));
    } else if (method == "retain") {
      text = retain(arg_str(args, 0), arg_str(args, 1));
    } else {
      throw std::runtime_error("missing method " + method);
    }
    return JsonVal::from_str(text);
  }
};

#endif
