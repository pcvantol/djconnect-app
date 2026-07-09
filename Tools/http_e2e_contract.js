#!/usr/bin/env node
"use strict";

const http = require("http");
const { contractFixture, startContractServer, assert, postJSON } = require("./ha_contract_fixture");

function getJSON(url, headers = {}) {
  return new Promise((resolve, reject) => {
    const request = http.request(
      url,
      {
        method: "GET",
        headers,
      },
      (response) => {
        const chunks = [];
        response.on("data", (chunk) => chunks.push(chunk));
        response.on("end", () => {
          try {
            resolve({
              statusCode: response.statusCode,
              body: JSON.parse(Buffer.concat(chunks).toString("utf8")),
            });
          } catch (error) {
            reject(error);
          }
        });
      }
    );
    request.on("error", reject);
    request.end();
  });
}

function getRaw(url, headers = {}) {
  return new Promise((resolve, reject) => {
    const request = http.request(url, { method: "GET", headers }, (response) => {
      const chunks = [];
      response.on("data", (chunk) => chunks.push(chunk));
      response.on("end", () => {
        resolve({
          statusCode: response.statusCode,
          headers: response.headers,
          body: Buffer.concat(chunks),
        });
      });
    });
    request.on("error", reject);
    request.end();
  });
}

function postRaw(url, body, headers = {}) {
  return new Promise((resolve, reject) => {
    const data = Buffer.isBuffer(body) ? body : Buffer.from(String(body));
    const request = http.request(
      url,
      {
        method: "POST",
        headers: {
          "content-length": data.length,
          ...headers,
        },
      },
      (response) => {
        const chunks = [];
        response.on("data", (chunk) => chunks.push(chunk));
        response.on("end", () => {
          try {
            resolve({
              statusCode: response.statusCode,
              body: JSON.parse(Buffer.concat(chunks).toString("utf8")),
            });
          } catch (error) {
            reject(error);
          }
        });
      }
    );
    request.on("error", reject);
    request.end(data);
  });
}

function authHeaders() {
  return { authorization: `Bearer ${contractFixture.djconnectToken}` };
}

function identity() {
  return {
    client_type: contractFixture.clientType,
    client_id: contractFixture.deviceID,
    device_id: contractFixture.deviceID,
    device_name: "CI iPhone",
    device_token: contractFixture.djconnectToken,
  };
}

function payload(extra = {}) {
  return {
    identity: identity(),
    client_type: contractFixture.clientType,
    client_id: contractFixture.deviceID,
    device_id: contractFixture.deviceID,
    device_name: "CI iPhone",
    ...extra,
  };
}

async function post(baseURL, path, body, expectedStatus = 200) {
  const response = await postJSON(`${baseURL}${path}`, body, authHeaders());
  assert(response.statusCode === expectedStatus, `${path} failed with HTTP ${response.statusCode}`);
  return response.body;
}

async function get(baseURL, path) {
  const response = await getJSON(`${baseURL}${path}`, authHeaders());
  assert(response.statusCode === 200, `${path} failed with HTTP ${response.statusCode}`);
  return response.body;
}

async function run() {
  const { server, observed, sockets, baseURL } = await startContractServer();
  try {
    const pair = await post(baseURL, "/api/djconnect/v1/pair", {
      client_type: contractFixture.clientType,
      device_id: contractFixture.deviceID,
      device_name: "CI iPhone",
      pair_code: "123456",
    });
    assert(pair.device_token === contractFixture.djconnectToken, "Pair HTTP contract failed");

    const status = await post(baseURL, "/api/djconnect/v1/status", payload({ capabilities: ["websocket"] }));
    assert(status.playback?.track_name === "Contract Track", "Status HTTP contract failed");

    const command = await post(baseURL, "/api/djconnect/v1/command", payload({ command: "play" }));
    assert(command.playback?.track_name === "Contract Track", "Command HTTP contract failed");

    const event = await post(baseURL, "/api/djconnect/v1/event", payload({ type: "foreground" }));
    assert(event.success === true, "Event HTTP contract failed");

    const rawAsk = await post(baseURL, "/api/djconnect/v1/ask_dj", payload({ text: "Raw Ask DJ request" }));
    assert(rawAsk.text === "Contract answer", "Raw Ask DJ HTTP contract failed");

    const legacyClear = await post(baseURL, "/api/djconnect/v1/ask_dj/clear", payload({ music_dna_key: "contract-key" }));
    assert(legacyClear.clear_revision === 1, "Legacy Ask DJ clear HTTP contract failed");

    const ask = await post(baseURL, "/api/djconnect/v1/ask_dj/message", payload({ text: "Tell me about this track" }));
    assert(ask.assistant_message?.text === "Contract answer", "Ask DJ HTTP contract failed");

    const idle = await post(baseURL, "/api/djconnect/v1/ask_dj/idle_suggestion", payload({ music_dna_key: "contract-key" }));
    assert(idle.assistant_message?.origin === "idle_suggestion", "Ask DJ idle suggestion HTTP contract failed");

    const history = await get(baseURL, "/api/djconnect/v1/ask_dj/history?since_revision=1");
    assert(history.history_revision === 1, "Ask DJ history HTTP contract failed");

    const exportHistory = await post(baseURL, "/api/djconnect/v1/ask_dj/history/export", payload({ app_version: "ci" }));
    assert(exportHistory.format === "djconnect.ask_dj.history.export", "Ask DJ history export HTTP contract failed");

    const clearHistory = await post(baseURL, "/api/djconnect/v1/ask_dj/history/clear", payload({ music_dna_key: "contract-key" }));
    assert(clearHistory.clear_revision === 1, "Ask DJ clear history HTTP contract failed");

    const historyState = await post(baseURL, "/api/djconnect/v1/ask_dj/history_state", payload({ since_revision: 0, clear_revision: 0 }));
    assert(historyState.ask_dj_clear_required === true, "Ask DJ history state HTTP contract failed");

    const profile = await post(baseURL, "/api/djconnect/v1/music_dna/profile", payload({ music_dna_key: "contract-key", language: "nl" }));
    assert(profile.enabled === true, "Music DNA profile HTTP contract failed");

    const settings = await post(baseURL, "/api/djconnect/v1/music_dna/settings", payload({ enabled: true, music_dna_key: "contract-key" }));
    assert(settings.generation === 8, "Music DNA settings HTTP contract failed");

    const clear = await post(baseURL, "/api/djconnect/v1/music_dna/clear", payload({ music_dna_key: "contract-key" }));
    assert(clear.success === true, "Music DNA clear HTTP contract failed");

    const exportedMusicDNA = await post(baseURL, "/api/djconnect/v1/music_dna/export", payload({ music_dna_key: "contract-key", app_version: "ci" }));
    assert(exportedMusicDNA.format === "djconnect.music_dna.export", "Music DNA export HTTP contract failed");

    const importedMusicDNA = await post(baseURL, "/api/djconnect/v1/music_dna/import", payload({ music_dna_key: "contract-key", profile: exportedMusicDNA }));
    assert(importedMusicDNA.generation === 10, "Music DNA import HTTP contract failed");

    const feed = await get(baseURL, "/api/djconnect/v1/music_discovery");
    assert(feed.sections?.[0]?.items?.[0]?.id === "disco-1", "Music Discovery feed HTTP contract failed");

    const refresh = await post(baseURL, "/api/djconnect/v1/music_discovery/refresh", payload({ music_dna_key: "contract-key" }));
    assert(refresh.revision === 3, "Music Discovery refresh HTTP contract failed");

    const play = await post(baseURL, "/api/djconnect/v1/music_discovery/play", payload({ discovery_item_id: "disco-1", section_id: "new_for_you", music_dna_key: "contract-key" }));
    assert(play.success === true, "Music Discovery play HTTP contract failed");

    const feedback = await post(baseURL, "/api/djconnect/v1/music_discovery/feedback", payload({ discovery_item_id: "disco-1", section_id: "new_for_you", feedback: "less_like_this", music_dna_key: "contract-key" }));
    assert(feedback.success === true, "Music Discovery feedback HTTP contract failed");

    const insight = await post(baseURL, "/api/djconnect/v1/track_insight", payload({ title: "Contract Track", artist: "Contract Artist" }));
    assert(insight.track_insight?.title === "Contract Insight", "Track Insight HTTP contract failed");

    const vibecast = await get(baseURL, "/api/djconnect/v1/vibecast?locale=nl-NL");
    assert(vibecast.enabled === true, "VibeCast HTTP contract failed");

    const pushRegister = await post(baseURL, "/api/djconnect/v1/push/register", payload({
      apns_token: "apns-contract-token",
      app_bundle_id: "dev.djconnect.ios",
      push_environment: "sandbox",
    }));
    assert(pushRegister.push_registered === true, "Push register HTTP contract failed");

    const pushBootstrap = await post(baseURL, "/api/djconnect/v1/push/bootstrap", payload({
      app_bundle_id: "dev.djconnect.ios",
      push_environment: "sandbox",
    }), 400);
    assert(pushBootstrap.error === "bootstrap_proof_unavailable", "Push bootstrap HTTP contract failed");

    const pushUnregister = await post(baseURL, "/api/djconnect/v1/push/unregister", payload({
      apns_token: "apns-contract-token",
      app_bundle_id: "dev.djconnect.ios",
      push_environment: "sandbox",
    }));
    assert(pushUnregister.push_registered === false, "Push unregister HTTP contract failed");

    const voice = await postRaw(`${baseURL}/api/djconnect/v1/voice`, Buffer.from("contract wav"), {
      ...authHeaders(),
      "content-type": "audio/wav",
      "x-djconnect-device-id": contractFixture.deviceID,
      "x-djconnect-client-type": contractFixture.clientType,
      "x-djconnect-text": "Contract voice",
    });
    assert(voice.statusCode === 200 && voice.body.success === true, "Voice HTTP contract failed");

    const tts = await getRaw(`${baseURL}/api/djconnect/v1/tts/contract.wav`, authHeaders());
    assert(tts.statusCode === 200 && tts.headers["content-type"] === "audio/wav", "TTS HTTP contract failed");

    const image = await getRaw(`${baseURL}/api/djconnect/v1/image_proxy/contract-image`, authHeaders());
    assert(image.statusCode === 200 && image.headers["content-type"] === "image/jpeg", "Image proxy HTTP contract failed");

    const debugVoice = await getRaw(`${baseURL}/api/djconnect/v1/debug/last_voice.wav`, authHeaders());
    assert(debugVoice.statusCode === 200 && debugVoice.headers["content-type"] === "audio/wav", "Voice debug HTTP contract failed");

    const expectedPaths = [
      "/api/djconnect/v1/pair",
      "/api/djconnect/v1/status",
      "/api/djconnect/v1/command",
      "/api/djconnect/v1/event",
      "/api/djconnect/v1/ask_dj",
      "/api/djconnect/v1/ask_dj/clear",
      "/api/djconnect/v1/ask_dj/message",
      "/api/djconnect/v1/ask_dj/idle_suggestion",
      "/api/djconnect/v1/ask_dj/history",
      "/api/djconnect/v1/ask_dj/history/export",
      "/api/djconnect/v1/ask_dj/history/clear",
      "/api/djconnect/v1/ask_dj/history_state",
      "/api/djconnect/v1/music_dna/profile",
      "/api/djconnect/v1/music_dna/settings",
      "/api/djconnect/v1/music_dna/clear",
      "/api/djconnect/v1/music_dna/export",
      "/api/djconnect/v1/music_dna/import",
      "/api/djconnect/v1/music_discovery",
      "/api/djconnect/v1/music_discovery/refresh",
      "/api/djconnect/v1/music_discovery/play",
      "/api/djconnect/v1/music_discovery/feedback",
      "/api/djconnect/v1/track_insight",
      "/api/djconnect/v1/vibecast",
      "/api/djconnect/v1/push/register",
      "/api/djconnect/v1/push/bootstrap",
      "/api/djconnect/v1/push/unregister",
      "/api/djconnect/v1/voice",
      "/api/djconnect/v1/tts/contract.wav",
      "/api/djconnect/v1/image_proxy/contract-image",
      "/api/djconnect/v1/debug/last_voice.wav",
    ];
    assert(
      JSON.stringify(observed.httpRequests.map((request) => request.path)) === JSON.stringify(expectedPaths),
      `Unexpected HTTP request order: ${JSON.stringify(observed.httpRequests)}`
    );
    assert(observed.sessionCalls === 0, "HTTP contract e2e should not call websocket session bootstrap");
    console.log(`HTTP contract e2e passed: ${observed.httpRequests.length} HTTP routes.`);
  } finally {
    for (const socket of sockets) socket.destroy();
    await new Promise((resolve) => server.close(resolve));
  }
}

run().catch((error) => {
  console.error(`HTTP contract e2e failed: ${error.message}`);
  process.exit(1);
});
