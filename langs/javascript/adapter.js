#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");

function loadClass(file, className) {
  const mod = require(path.resolve(file));
  const cls = mod[className] || mod.default || mod;
  if (typeof cls !== "function") {
    throw new Error("missing class " + className);
  }
  return cls;
}

function main() {
  const file = process.argv[2];
  const className = process.argv[3];
  const casesPath = process.argv[4];
  const Cls = loadClass(file, className);
  const cases = JSON.parse(fs.readFileSync(casesPath, "utf8"));
  const failed = [];
  let passed = 0;
  for (const c of cases) {
    const obj = new Cls();
    let ok = true;
    for (let i = 0; i < c.calls.length; i++) {
      const call = c.calls[i];
      const name = call.m.includes("_")
        ? call.m
            .split("_")
            .map((p, i) => (i === 0 ? p : p[0].toUpperCase() + p.slice(1)))
            .join("")
        : call.m;
      const fn = obj[name];
      let actual;
      try {
        actual = fn.apply(obj, call.a);
      } catch (err) {
        failed.push({
          case: c.id,
          index: i,
          method: call.m,
          expected: call.e,
          actual: "exc:" + err.name,
        });
        ok = false;
        break;
      }
      const exp = call.e;
      const same = JSON.stringify(actual) === JSON.stringify(exp);
      if (!same) {
        failed.push({
          case: c.id,
          index: i,
          method: call.m,
          expected: exp,
          actual: actual,
        });
        ok = false;
        break;
      }
    }
    if (ok) passed += 1;
  }
  process.stdout.write(JSON.stringify({ passed, failed }) + "\n");
  process.exit(failed.length ? 1 : 0);
}

main();
