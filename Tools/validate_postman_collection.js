#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const collectionPath = process.argv[2] || "docs/postman/djconnect-local-device-api.postman_collection.json";
const expectedSchema = "https://schema.getpostman.com/json/collection/v2.1.0/collection.json";
const expectedVariables = new Set([
  "client_api_url",
  "pair_code",
  "device_id",
  "client_type",
  "device_token",
  "ha_local_url"
]);
const expectedRequests = new Map([
  ["GET /api/device/pairing-info", { method: "GET", path: "/api/device/pairing-info", auth: false, jsonBody: false }],
  ["GET /api/device/info", { method: "GET", path: "/api/device/info", auth: false, jsonBody: false }],
  ["POST /api/device/pair", { method: "POST", path: "/api/device/pair", auth: false, jsonBody: true }],
  ["POST /api/device/command", { method: "POST", path: "/api/device/command", auth: true, jsonBody: true }],
  ["POST /api/device/dj_response", { method: "POST", path: "/api/device/dj_response", auth: true, jsonBody: true }],
  ["POST /api/device/forget", { method: "POST", path: "/api/device/forget", auth: true, jsonBody: false }]
]);

const errors = [];

function fail(message) {
  errors.push(message);
}

function readCollection(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch (error) {
    fail(`Could not read valid JSON from ${filePath}: ${error.message}`);
    return null;
  }
}

function flattenItems(items, result = []) {
  for (const item of items || []) {
    if (Array.isArray(item.item)) {
      flattenItems(item.item, result);
    } else if (item.request) {
      result.push(item);
    }
  }
  return result;
}

function headerValue(request, key) {
  return (request.header || []).find((header) => header.key?.toLowerCase() === key.toLowerCase())?.value;
}

function assertCollectionMetadata(collection) {
  if (collection.info?.schema !== expectedSchema) {
    fail(`Unexpected Postman schema: ${collection.info?.schema || "missing"}`);
  }
  if (collection.info?.name !== "DJConnect Local Client API") {
    fail(`Unexpected collection name: ${collection.info?.name || "missing"}`);
  }
}

function assertVariables(collection) {
  const variables = new Map((collection.variable || []).map((variable) => [variable.key, variable.value]));
  for (const key of expectedVariables) {
    if (!variables.has(key)) {
      fail(`Missing collection variable: ${key}`);
    }
  }
  for (const key of variables.keys()) {
    if (!expectedVariables.has(key)) {
      fail(`Unexpected collection variable: ${key}`);
    }
  }
  const deviceToken = String(variables.get("device_token") ?? "");
  if (deviceToken.trim() !== "") {
    fail("device_token must be empty in the committed Postman collection");
  }
}

function normalizedPath(request) {
  const raw = request.url?.raw || "";
  return raw.replace("{{client_api_url}}", "");
}

function substituteVariables(raw) {
  return raw
    .replaceAll("{{pair_code}}", "123456")
    .replaceAll("{{device_id}}", "djconnect-ios-TESTDEVICE")
    .replaceAll("{{client_type}}", "ios")
    .replaceAll("{{device_token}}", "test-token")
    .replaceAll("{{ha_local_url}}", "http://homeassistant.local:8123")
    .replaceAll("{{client_api_url}}", "http://127.0.0.1:12345");
}

function assertRequest(item) {
  const expected = expectedRequests.get(item.name);
  if (!expected) {
    fail(`Unexpected request in collection: ${item.name}`);
    return;
  }
  const request = item.request;
  if (request.method !== expected.method) {
    fail(`${item.name}: expected method ${expected.method}, got ${request.method}`);
  }
  if (normalizedPath(request) !== expected.path) {
    fail(`${item.name}: expected path ${expected.path}, got ${normalizedPath(request) || "missing"}`);
  }
  if (!request.description || request.description.trim().length < 20) {
    fail(`${item.name}: request description is missing or too short`);
  }
  const authorization = headerValue(request, "Authorization") || "";
  if (expected.auth && authorization !== "Bearer {{device_token}}") {
    fail(`${item.name}: expected Authorization header "Bearer {{device_token}}"`);
  }
  if (!expected.auth && authorization) {
    fail(`${item.name}: must not include an Authorization header`);
  }
  const rawBody = request.body?.raw;
  if (expected.jsonBody) {
    if (headerValue(request, "Content-Type") !== "application/json") {
      fail(`${item.name}: JSON request must include Content-Type application/json`);
    }
    try {
      JSON.parse(substituteVariables(rawBody || ""));
    } catch (error) {
      fail(`${item.name}: raw JSON body is invalid after variable substitution: ${error.message}`);
    }
  }
}

function main() {
  const resolvedPath = path.resolve(collectionPath);
  const collection = readCollection(resolvedPath);
  if (!collection) {
    process.exit(1);
  }

  assertCollectionMetadata(collection);
  assertVariables(collection);

  const requests = flattenItems(collection.item);
  const requestNames = new Set(requests.map((item) => item.name));
  for (const name of expectedRequests.keys()) {
    if (!requestNames.has(name)) {
      fail(`Missing request: ${name}`);
    }
  }
  for (const item of requests) {
    assertRequest(item);
  }

  if (errors.length > 0) {
    console.error("Postman collection validation failed:");
    for (const error of errors) {
      console.error(`- ${error}`);
    }
    process.exit(1);
  }

  console.log(`Validated ${requests.length} Postman requests in ${collectionPath}`);
}

main();
