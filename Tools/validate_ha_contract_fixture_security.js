#!/usr/bin/env node
"use strict";

const { spawn } = require("child_process");
const { contractFixture } = require("./ha_contract_fixture");

function fail(message) {
  throw new Error(message);
}

function assert(condition, message) {
  if (!condition) fail(message);
}

function assertNoSecret(output, label) {
  const secrets = [
    contractFixture.djconnectToken,
    contractFixture.webSocketToken,
    "Authorization",
    "access_token",
    "device_token",
    "bootstrap_proof",
  ];
  for (const secret of secrets) {
    assert(!output.includes(secret), `${label} leaked ${secret}`);
  }
}

async function captureFixtureStartup() {
  return await new Promise((resolve, reject) => {
    const child = spawn(process.execPath, ["Tools/ha_contract_fixture.js"], {
      cwd: process.cwd(),
      stdio: ["ignore", "pipe", "pipe"],
    });
    let output = "";
    let settled = false;
    const timeout = setTimeout(() => {
      if (!settled) {
        settled = true;
        child.kill("SIGTERM");
        reject(new Error("Fixture startup timed out"));
      }
    }, 5000);
    child.stdout.on("data", (chunk) => {
      output += chunk.toString("utf8");
      if (output.includes("DJConnect HA contract fixture listening at")) {
        settled = true;
        clearTimeout(timeout);
        child.kill("SIGTERM");
        resolve(output);
      }
    });
    child.stderr.on("data", (chunk) => {
      output += chunk.toString("utf8");
    });
    child.on("error", (error) => {
      if (!settled) {
        settled = true;
        clearTimeout(timeout);
        reject(error);
      }
    });
    child.on("exit", (code, signal) => {
      if (!settled && code !== 0 && signal !== "SIGTERM") {
        settled = true;
        clearTimeout(timeout);
        reject(new Error(`Fixture exited early: code=${code} signal=${signal} output=${output}`));
      }
    });
  });
}

async function run() {
  assert(contractFixture.routes.length >= 13, "Fixture route list is unexpectedly small");
  assertNoSecret(JSON.stringify({ routes: contractFixture.routes }), "route metadata");
  const startupOutput = await captureFixtureStartup();
  assert(startupOutput.includes("127.0.0.1"), "Fixture startup did not print local URL");
  assertNoSecret(startupOutput, "fixture startup output");
  console.log("HA contract fixture security validation passed.");
}

run().catch((error) => {
  console.error(`HA contract fixture security validation failed: ${error.message}`);
  process.exit(1);
});
