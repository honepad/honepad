"use strict";

// JSON.stringify omits undefined object fields and turns NaN and Infinity
// into null. Failure rows need those values as strings so the report still
// parses, and so they do not compare equal to null.

function nonJsonKind(value) {
  if (value === undefined) {
    return "undefined";
  }
  if (typeof value === "number") {
    if (Number.isNaN(value)) {
      return "NaN";
    }
    if (value === Infinity) {
      return "Infinity";
    }
    if (value === -Infinity) {
      return "-Infinity";
    }
  }
  if (typeof value === "bigint") {
    return "bigint:" + value.toString();
  }
  if (typeof value === "function") {
    return "function";
  }
  if (typeof value === "symbol") {
    return "symbol";
  }
  if (value instanceof Number) {
    return nonJsonKind(value.valueOf());
  }
  if (value instanceof Date && Number.isNaN(value.getTime())) {
    return "Invalid Date";
  }
  return null;
}

const TO_JSON_MARK = Symbol("toJSON");

function producedJson(value) {
  if (
    value === null ||
    typeof value !== "object" ||
    typeof value.toJSON !== "function" ||
    (value instanceof Date && Number.isNaN(value.getTime()))
  ) {
    return value;
  }
  try {
    const produced = value.toJSON();
    if (produced === value) {
      return value;
    }
    return { [TO_JSON_MARK]: "replaced", payload: produced };
  } catch (_err) {
    return { [TO_JSON_MARK]: "failed" };
  }
}

function containsNonJson(value, seen) {
  if (nonJsonKind(value) !== null) {
    return true;
  }
  if (typeof value !== "object" || value === null) {
    return false;
  }
  if (seen.has(value)) {
    return true;
  }
  seen.add(value);
  try {
    const produced = producedJson(value);
    if (produced && produced[TO_JSON_MARK] === "failed") {
      return true;
    }
    if (produced && produced[TO_JSON_MARK] === "replaced") {
      return containsNonJson(produced.payload, seen);
    }
    if (Array.isArray(value)) {
      for (let i = 0; i < value.length; i++) {
        if (!Object.prototype.hasOwnProperty.call(value, i)) {
          return true;
        }
        if (containsNonJson(value[i], seen)) {
          return true;
        }
      }
      return false;
    }
    for (const key of Object.keys(value)) {
      if (containsNonJson(value[key], seen)) {
        return true;
      }
    }
    return false;
  } finally {
    seen.delete(value);
  }
}

function sameResult(actual, expected) {
  try {
    if (containsNonJson(actual, new Set())) {
      return false;
    }
    return JSON.stringify(actual) === JSON.stringify(expected);
  } catch (_err) {
    return false;
  }
}

function displayActual(value, seen) {
  if (seen === undefined) {
    seen = new Set();
  }
  const kind = nonJsonKind(value);
  if (kind !== null) {
    return kind;
  }
  if (typeof value !== "object" || value === null) {
    return value;
  }
  if (seen.has(value)) {
    return "circular";
  }
  seen.add(value);
  try {
    const produced = producedJson(value);
    if (produced && produced[TO_JSON_MARK] === "failed") {
      return "unencodable";
    }
    if (produced && produced[TO_JSON_MARK] === "replaced") {
      return displayActual(produced.payload, seen);
    }
    if (Array.isArray(value)) {
      const out = [];
      for (let i = 0; i < value.length; i++) {
        if (!Object.prototype.hasOwnProperty.call(value, i)) {
          out.push("undefined");
        } else {
          out.push(displayActual(value[i], seen));
        }
      }
      return out;
    }
    const out = {};
    for (const key of Object.keys(value)) {
      out[key] = displayActual(value[key], seen);
    }
    return out;
  } finally {
    seen.delete(value);
  }
}

module.exports = { sameResult, displayActual };
