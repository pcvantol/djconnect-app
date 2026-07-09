#!/usr/bin/env node
"use strict";

const crypto = require("crypto");
const http = require("http");
const net = require("net");

const DJCONNECT_TOKEN = "djci_contract_test";
const WS_TOKEN = "ha_ws_contract_short_lived";
const DEVICE_ID = "djconnect-ios-contract";
const CLIENT_TYPE = "ios";

const routes = [
  "djconnect/command",
  "djconnect/ask_dj/message",
  "djconnect/ask_dj/history",
  "djconnect/ask_dj/history/clear",
  "djconnect/ask_dj/history/state",
  "djconnect/ask_dj/idle_suggestion",
  "djconnect/music_dna/profile",
  "djconnect/music_dna/settings",
  "djconnect/music_dna/clear",
  "djconnect/music_dna/import",
  "djconnect/music_dna/export",
  "djconnect/music_discovery/feed",
  "djconnect/music_discovery/refresh",
  "djconnect/music_discovery/play",
  "djconnect/music_discovery/feedback",
  "djconnect/track_insight",
];

const contractFixture = {
  djconnectToken: DJCONNECT_TOKEN,
  webSocketToken: WS_TOKEN,
  deviceID: DEVICE_ID,
  clientType: CLIENT_TYPE,
  routes,
};

function fail(message) {
  throw new Error(message);
}

function assert(condition, message) {
  if (!condition) fail(message);
}

function readRequestBody(request) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    request.on("data", (chunk) => chunks.push(chunk));
    request.on("end", () => resolve(Buffer.concat(chunks)));
    request.on("error", reject);
  });
}

function jsonResponse(response, statusCode, body) {
  const data = Buffer.from(JSON.stringify(body));
  response.writeHead(statusCode, {
    "content-type": "application/json",
    "content-length": data.length,
  });
  response.end(data);
}

function rawResponse(response, statusCode, body, contentType) {
  const data = Buffer.isBuffer(body) ? body : Buffer.from(String(body));
  response.writeHead(statusCode, {
    "content-type": contentType,
    "content-length": data.length,
  });
  response.end(data);
}

function assertAuthenticatedRequest(request) {
  assert(request.headers.authorization === `Bearer ${DJCONNECT_TOKEN}`, `${request.method} ${request.url} missing DJConnect bearer`);
}

function bodyIdentity(body) {
  return body.identity || body.payload?.identity || body;
}

function assertHTTPIdentity(body, route) {
  const identity = bodyIdentity(body);
  assert(identity.device_id === DEVICE_ID || identity.deviceID === DEVICE_ID || body.device_id === DEVICE_ID, `${route} missing device_id`);
  assert(identity.client_type === CLIENT_TYPE || identity.clientType === CLIENT_TYPE || body.client_type === CLIENT_TYPE, `${route} missing client_type`);
}

function discoveryFeedResponse() {
  return {
    success: true,
    enabled: true,
    revision: 3,
    sections: [
      {
        id: "new_for_you",
        title: "New for you",
        items: [
          {
            id: "disco-1",
            kind: "track",
            title: "Contract Track",
            subtitle: "Contract Artist",
            uri: "spotify:track:contract",
            reason: "Contract reason",
            reason_sources: ["music_dna"],
            confidence: "high",
          },
        ],
      },
    ],
  };
}

function askDJResponse(extra = {}) {
  return {
    success: true,
    text: "Contract answer",
    dj_text: "Contract answer",
    history_revision: 2,
    clear_revision: 0,
    assistant_message: { role: "assistant", text: "Contract answer", origin: extra.origin || "message" },
    actions: [],
    sources: [],
    ...extra,
  };
}

function askDJHistoryResponse(extra = {}) {
  return {
    success: true,
    user_id: "contract-user",
    history_revision: 1,
    clear_revision: 0,
    history_limit: 50,
    history_trimmed_before: null,
    history_trimmed_count: 0,
    server_time: "2026-07-09T00:00:00.000Z",
    messages: [],
    ...extra,
  };
}

function musicDNAProfileResponse(extra = {}) {
  return {
    success: true,
    music_dna_key: "contract-key",
    enabled: true,
    generation: 7,
    profile: { summary: "Contract Music DNA", track_count: 12 },
    ...extra,
  };
}

function musicDNAExportResponse() {
  return {
    success: true,
    format: "djconnect.music_dna.export",
    schema_version: 1,
    exported_at: "2026-07-09T00:00:00.000Z",
    exported_by_client_type: CLIENT_TYPE,
    app_version: "ci",
    profile: musicDNAProfileResponse(),
  };
}

async function handleHTTPContractRoute(request, response, observed) {
  const path = new URL(request.url, "http://127.0.0.1").pathname;
  if (request.method === "POST" && path === "/api/djconnect/v1/pair") {
    const body = JSON.parse((await readRequestBody(request)).toString("utf8"));
    assert(body.device_id === DEVICE_ID, "Pair request missing device_id");
    assert(body.client_type === CLIENT_TYPE, "Pair request missing client_type");
    assert(body.pair_code === "123456", "Pair request missing pair_code");
    observed.httpRequests.push({ method: request.method, path });
    jsonResponse(response, 200, {
      success: true,
      client_type: CLIENT_TYPE,
      device_token: DJCONNECT_TOKEN,
      assist_pipeline_id: "contract-pipeline",
      api_base: "/api/djconnect/v1",
      voice_path: "/api/djconnect/v1/voice",
      status_path: "/api/djconnect/v1/status",
      event_path: "/api/djconnect/v1/event",
      ha_install_id: "ha-install-contract",
      pairing_session_id: "pairing-contract",
      ask_dj_supported: true,
      music_backend_available: true,
    });
    return true;
  }

  if (request.method === "POST" && path === "/api/djconnect/v1/websocket/session") {
    observed.sessionCalls += 1;
    assertAuthenticatedRequest(request);
    const body = JSON.parse((await readRequestBody(request)).toString("utf8"));
    assert(body.device_id === DEVICE_ID, "Session request missing device_id");
    assert(body.client_type === CLIENT_TYPE, "Session request missing client_type");
    assert(body.access_token === undefined, "Session request leaked HA access_token");
    assert(body.home_assistant_token === undefined, "Session request leaked HA token");
    assert(Array.isArray(body.requested_commands), "Session request missing requested_commands");
    jsonResponse(response, 200, {
      success: true,
      access_token: WS_TOKEN,
      expires_at: new Date(Date.now() + 10 * 60 * 1000).toISOString(),
      commands: routes,
    });
    return true;
  }

  if (!path.startsWith("/api/djconnect/v1/")) {
    return false;
  }

  assertAuthenticatedRequest(request);
  observed.httpRequests.push({ method: request.method, path });

  if (request.method === "POST" && path === "/api/djconnect/v1/status") {
    const body = JSON.parse((await readRequestBody(request)).toString("utf8"));
    assertHTTPIdentity(body, path);
    jsonResponse(response, 200, {
      success: true,
      playback: {
        has_playback: true,
        is_playing: true,
        track_name: "Contract Track",
        artist_name: "Contract Artist",
      },
      backend_available: true,
      remote_supported: true,
      music_backend_available: true,
    });
    return true;
  }

  if (request.method === "POST" && path === "/api/djconnect/v1/command") {
    const body = JSON.parse((await readRequestBody(request)).toString("utf8"));
    assertHTTPIdentity(body, path);
    assert(body.command === "play", "Command request did not carry command=play");
    jsonResponse(response, 200, {
      success: true,
      playback: { has_playback: true, track_name: "Contract Track" },
    });
    return true;
  }

  if (request.method === "POST" && path === "/api/djconnect/v1/event") {
    const body = JSON.parse((await readRequestBody(request)).toString("utf8"));
    assertHTTPIdentity(body, path);
    assert(body.type === "foreground" || body.event === "foreground", "Event request missing event type");
    jsonResponse(response, 200, { success: true });
    return true;
  }

  if (request.method === "POST" && path === "/api/djconnect/v1/ask_dj") {
    const body = JSON.parse((await readRequestBody(request)).toString("utf8"));
    assertHTTPIdentity(body, path);
    assert(typeof body.text === "string" && body.text.length > 0, "Raw Ask DJ request missing text");
    jsonResponse(response, 200, askDJResponse());
    return true;
  }

  if (request.method === "POST" && path === "/api/djconnect/v1/ask_dj/clear") {
    const body = JSON.parse((await readRequestBody(request)).toString("utf8"));
    assertHTTPIdentity(body, path);
    jsonResponse(response, 200, askDJHistoryResponse({ history_revision: 0, clear_revision: 1, messages: [] }));
    return true;
  }

  if (request.method === "POST" && path === "/api/djconnect/v1/ask_dj/message") {
    const body = JSON.parse((await readRequestBody(request)).toString("utf8"));
    assertHTTPIdentity(body, path);
    assert(typeof body.text === "string" && body.text.length > 0, "Ask DJ request missing text");
    jsonResponse(response, 200, askDJResponse());
    return true;
  }

  if (request.method === "POST" && path === "/api/djconnect/v1/ask_dj/idle_suggestion") {
    const body = JSON.parse((await readRequestBody(request)).toString("utf8"));
    assertHTTPIdentity(body, path);
    jsonResponse(response, 200, askDJResponse({ origin: "idle_suggestion" }));
    return true;
  }

  if (request.method === "GET" && path === "/api/djconnect/v1/ask_dj/history") {
    jsonResponse(response, 200, askDJHistoryResponse());
    return true;
  }

  if (request.method === "POST" && path === "/api/djconnect/v1/ask_dj/history/export") {
    const body = JSON.parse((await readRequestBody(request)).toString("utf8"));
    assertHTTPIdentity(body, path);
    jsonResponse(response, 200, {
      ...askDJHistoryResponse(),
      format: "djconnect.ask_dj.history.export",
      schema_version: 1,
      exported_at: "2026-07-09T00:00:00.000Z",
      exported_by_client_type: CLIENT_TYPE,
      app_version: "ci",
    });
    return true;
  }

  if (request.method === "POST" && path === "/api/djconnect/v1/ask_dj/history/clear") {
    const body = JSON.parse((await readRequestBody(request)).toString("utf8"));
    assertHTTPIdentity(body, path);
    jsonResponse(response, 200, askDJHistoryResponse({ history_revision: 0, clear_revision: 1, messages: [] }));
    return true;
  }

  if (request.method === "POST" && path === "/api/djconnect/v1/ask_dj/history_state") {
    const body = JSON.parse((await readRequestBody(request)).toString("utf8"));
    assertHTTPIdentity(body, path);
    jsonResponse(response, 200, {
      success: true,
      user_id: "contract-user",
      history_revision: 1,
      clear_revision: 1,
      history_limit: 50,
      history_trimmed_before: null,
      history_trimmed_count: 0,
      ask_dj_clear_required: true,
      server_time: "2026-07-09T00:00:00.000Z",
    });
    return true;
  }

  if (request.method === "POST" && path === "/api/djconnect/v1/music_dna/profile") {
    const body = JSON.parse((await readRequestBody(request)).toString("utf8"));
    assertHTTPIdentity(body, path);
    jsonResponse(response, 200, musicDNAProfileResponse());
    return true;
  }

  if (request.method === "POST" && path === "/api/djconnect/v1/music_dna/settings") {
    const body = JSON.parse((await readRequestBody(request)).toString("utf8"));
    assertHTTPIdentity(body, path);
    assert(body.enabled === true, "Music DNA settings request missing enabled=true");
    jsonResponse(response, 200, musicDNAProfileResponse({ generation: 8, profile: { summary: "Music DNA enabled" } }));
    return true;
  }

  if (request.method === "POST" && path === "/api/djconnect/v1/music_dna/clear") {
    const body = JSON.parse((await readRequestBody(request)).toString("utf8"));
    assertHTTPIdentity(body, path);
    jsonResponse(response, 200, musicDNAProfileResponse({ generation: 9, profile: {} }));
    return true;
  }

  if (request.method === "POST" && path === "/api/djconnect/v1/music_dna/import") {
    const body = JSON.parse((await readRequestBody(request)).toString("utf8"));
    assertHTTPIdentity(body, path);
    assert(body.profile?.format === "djconnect.music_dna.export", "Music DNA import request missing export envelope");
    jsonResponse(response, 200, musicDNAProfileResponse({ generation: 10, profile: { summary: "Imported Music DNA" } }));
    return true;
  }

  if (request.method === "POST" && path === "/api/djconnect/v1/music_dna/export") {
    const body = JSON.parse((await readRequestBody(request)).toString("utf8"));
    assertHTTPIdentity(body, path);
    jsonResponse(response, 200, musicDNAExportResponse());
    return true;
  }

  if (request.method === "GET" && path === "/api/djconnect/v1/music_discovery") {
    jsonResponse(response, 200, discoveryFeedResponse());
    return true;
  }

  if (request.method === "POST" && path === "/api/djconnect/v1/music_discovery/refresh") {
    const body = JSON.parse((await readRequestBody(request)).toString("utf8"));
    assertHTTPIdentity(body, path);
    jsonResponse(response, 200, discoveryFeedResponse());
    return true;
  }

  if (request.method === "POST" && path === "/api/djconnect/v1/music_discovery/play") {
    const body = JSON.parse((await readRequestBody(request)).toString("utf8"));
    assertHTTPIdentity(body, path);
    assert(body.discovery_item_id === "disco-1", "Music Discovery play request missing discovery_item_id");
    assert(body.section_id === "new_for_you", "Music Discovery play request missing section_id");
    jsonResponse(response, 200, { success: true });
    return true;
  }

  if (request.method === "POST" && path === "/api/djconnect/v1/music_discovery/feedback") {
    const body = JSON.parse((await readRequestBody(request)).toString("utf8"));
    assertHTTPIdentity(body, path);
    assert(body.feedback === "less_like_this", "Music Discovery feedback request missing feedback");
    jsonResponse(response, 200, { success: true });
    return true;
  }

  if (request.method === "POST" && path === "/api/djconnect/v1/track_insight") {
    const body = JSON.parse((await readRequestBody(request)).toString("utf8"));
    assertHTTPIdentity(body, path);
    jsonResponse(response, 200, {
      success: true,
      track_insight: {
        title: "Contract Insight",
        artist: "Contract Artist",
        energy: 72,
        sections: [{ title: "Energy", value: "72" }],
      },
    });
    return true;
  }

  if (request.method === "GET" && path === "/api/djconnect/v1/vibecast") {
    jsonResponse(response, 200, {
      enabled: true,
      items: [{ id: "fact", kind: "track_fact", text: [{ type: "text", value: "Contract VibeCast" }] }],
    });
    return true;
  }

  if (request.method === "POST" && path === "/api/djconnect/v1/push/register") {
    const body = JSON.parse((await readRequestBody(request)).toString("utf8"));
    assertHTTPIdentity(body, path);
    assert(body.apns_token === "apns-contract-token", "Push register request missing APNs token");
    jsonResponse(response, 200, {
      success: true,
      push_supported: true,
      push_registered: true,
      push_environment: body.push_environment || body.apns_environment || "sandbox",
      last_push_error: null,
    });
    return true;
  }

  if (request.method === "POST" && path === "/api/djconnect/v1/push/unregister") {
    const body = JSON.parse((await readRequestBody(request)).toString("utf8"));
    assertHTTPIdentity(body, path);
    jsonResponse(response, 200, {
      success: true,
      push_supported: true,
      push_registered: false,
      push_environment: body.push_environment || body.apns_environment || "sandbox",
      last_push_error: null,
    });
    return true;
  }

  if (request.method === "POST" && path === "/api/djconnect/v1/voice") {
    assert(request.headers["x-djconnect-device-id"] === DEVICE_ID, "Voice request missing X-DJConnect-Device-ID");
    assert(request.headers["x-djconnect-client-type"] === CLIENT_TYPE, "Voice request missing X-DJConnect-Client-Type");
    const body = await readRequestBody(request);
    assert(body.length > 0, "Voice request missing body");
    jsonResponse(response, 200, {
      success: true,
      text: "Contract DJ response",
      dj_text: "Contract DJ response",
      recognized_text: request.headers["x-djconnect-text"] || "Contract voice",
      audio_type: null,
      music_dna_key: "contract-key",
    });
    return true;
  }

  if (request.method === "GET" && /^\/api\/djconnect\/v1\/tts\/[^/]+\.(wav|mp3)$/.test(path)) {
    rawResponse(response, 200, Buffer.from("RIFF....WAVEfmt "), "audio/wav");
    return true;
  }

  if (request.method === "GET" && /^\/api\/djconnect\/v1\/image_proxy\/[^/]+$/.test(path)) {
    rawResponse(response, 200, Buffer.from([0xff, 0xd8, 0xff, 0xd9]), "image/jpeg");
    return true;
  }

  if (request.method === "GET" && path === "/api/djconnect/v1/debug/last_voice.wav") {
    rawResponse(response, 200, Buffer.from("RIFF....WAVEfmt "), "audio/wav");
    return true;
  }

  return false;
}

function websocketAcceptValue(key) {
  return crypto
    .createHash("sha1")
    .update(`${key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11`)
    .digest("base64");
}

function encodeFrame(payload, { masked = false } = {}) {
  const data = Buffer.from(payload);
  const header = [];
  header.push(0x81);
  if (data.length < 126) {
    header.push((masked ? 0x80 : 0) | data.length);
  } else if (data.length < 65536) {
    header.push((masked ? 0x80 : 0) | 126, (data.length >> 8) & 0xff, data.length & 0xff);
  } else {
    fail("Frame too large for contract test");
  }
  let frame = Buffer.concat([Buffer.from(header), data]);
  if (masked) {
    const mask = crypto.randomBytes(4);
    const start = header.length + 4;
    frame = Buffer.concat([Buffer.from(header), mask, data]);
    for (let index = 0; index < data.length; index += 1) {
      frame[start + index] = data[index] ^ mask[index % 4];
    }
  }
  return frame;
}

function decodeFrame(buffer) {
  if (buffer.length < 2) return null;
  const first = buffer[0];
  const second = buffer[1];
  const opcode = first & 0x0f;
  const masked = (second & 0x80) !== 0;
  let length = second & 0x7f;
  let offset = 2;
  if (length === 126) {
    if (buffer.length < offset + 2) return null;
    length = buffer.readUInt16BE(offset);
    offset += 2;
  } else if (length === 127) {
    fail("64-bit websocket frames are not supported by this contract test");
  }
  let mask;
  if (masked) {
    if (buffer.length < offset + 4) return null;
    mask = buffer.subarray(offset, offset + 4);
    offset += 4;
  }
  if (buffer.length < offset + length) return null;
  const payload = Buffer.from(buffer.subarray(offset, offset + length));
  if (masked) {
    for (let index = 0; index < payload.length; index += 1) {
      payload[index] = payload[index] ^ mask[index % 4];
    }
  }
  return {
    opcode,
    text: payload.toString("utf8"),
    consumed: offset + length,
  };
}

function sendJSON(socket, value) {
  socket.write(encodeFrame(JSON.stringify(value)));
}

function resultForMessage(message) {
  const type = message.type;
  const identity = message.identity || message.payload?.identity || {};
  assert(identity.device_id === DEVICE_ID || identity.deviceID === DEVICE_ID, `${type} missing device identity`);
  assert(identity.client_type === CLIENT_TYPE || identity.clientType === CLIENT_TYPE, `${type} missing client type`);

  if (type === "djconnect/capabilities") {
    return {
      id: message.id,
      type: "result",
      success: true,
      result: {
        success: true,
        websocket_supported: true,
        transports: { websocket: true },
        commands: routes,
        features: {
          music_dna: true,
          music_discovery: true,
          music_discovery_feedback: true,
        },
      },
    };
  }

  if (type === "djconnect/music_dna/profile") {
    return {
      id: message.id,
      type: "result",
      success: true,
      result: {
        success: true,
        music_dna_key: "contract-key",
        enabled: true,
        generation: 7,
        profile: { summary: "Contract Music DNA", track_count: 12 },
      },
    };
  }

  if (type === "djconnect/music_dna/settings") {
    assert(message.payload?.enabled === true || message.enabled === true, "Music DNA settings did not carry enabled=true");
    return {
      id: message.id,
      type: "result",
      success: true,
      result: {
        success: true,
        music_dna_key: "contract-key",
        enabled: true,
        generation: 8,
        profile: { summary: "Music DNA enabled" },
      },
    };
  }

  if (type === "djconnect/music_dna/clear") {
    return {
      id: message.id,
      type: "result",
      success: true,
      result: {
        success: true,
        music_dna_key: "contract-key",
        enabled: true,
        generation: 9,
        profile: {},
      },
    };
  }

  if (type === "djconnect/music_dna/import") {
    assert(message.payload?.profile?.format === "djconnect.music_dna.export" || message.profile?.format === "djconnect.music_dna.export", "Music DNA import did not carry export envelope");
    return {
      id: message.id,
      type: "result",
      success: true,
      result: musicDNAProfileResponse({ generation: 10, profile: { summary: "Imported Music DNA" } }),
    };
  }

  if (type === "djconnect/music_dna/export") {
    return {
      id: message.id,
      type: "result",
      success: true,
      result: musicDNAExportResponse(),
    };
  }

  if (type === "djconnect/music_discovery/feed" || type === "djconnect/music_discovery/refresh") {
    return {
      id: message.id,
      type: "result",
      success: true,
      result: {
        success: true,
        enabled: true,
        revision: 3,
        sections: [
          {
            id: "new_for_you",
            title: "New for you",
            items: [
              {
                id: "disco-1",
                kind: "track",
                title: "Contract Track",
                subtitle: "Contract Artist",
                uri: "spotify:track:contract",
                reason: "Contract reason",
                reason_sources: ["music_dna"],
                confidence: "high",
              },
            ],
          },
        ],
      },
    };
  }

  if (type === "djconnect/music_discovery/play" || type === "djconnect/music_discovery/feedback") {
    return {
      id: message.id,
      type: "result",
      success: true,
      result: { success: true },
    };
  }

  if (type === "djconnect/track_insight") {
    return {
      id: message.id,
      type: "result",
      success: true,
      result: {
        success: true,
        title: "Contract Insight",
        artist: "Contract Artist",
        energy: 72,
        sections: [{ title: "Energy", value: "72" }],
      },
    };
  }

  if (type === "djconnect/command") {
    return {
      id: message.id,
      type: "result",
      success: true,
      result: { success: true, playback: { has_playback: true, track_name: "Contract Track" } },
    };
  }

  if (type === "djconnect/ask_dj/history" || type === "djconnect/ask_dj/history/clear") {
    return {
      id: message.id,
      type: "result",
      success: true,
      result: { history_revision: 1, clear_revision: 0, messages: [] },
    };
  }

  if (type === "djconnect/ask_dj/history/state") {
    return {
      id: message.id,
      type: "result",
      success: true,
      result: {
        success: true,
        user_id: "contract-user",
        history_revision: 1,
        clear_revision: 1,
        history_limit: 50,
        history_trimmed_before: null,
        history_trimmed_count: 0,
        ask_dj_clear_required: true,
        server_time: "2026-07-09T00:00:00.000Z",
      },
    };
  }

  if (type === "djconnect/ask_dj/message" || type === "djconnect/ask_dj/idle_suggestion") {
    return {
      id: message.id,
      type: "result",
      success: true,
      result: askDJResponse({ origin: type === "djconnect/ask_dj/idle_suggestion" ? "idle_suggestion" : "message" }),
    };
  }

  return {
    id: message.id,
    type: "result",
    success: false,
    error: { code: "unsupported", message: `Unsupported route ${type}` },
  };
}

function startContractServer() {
  const observed = {
    sessionCalls: 0,
    httpRequests: [],
    websocketMessages: [],
  };
  const sockets = new Set();
  const server = http.createServer(async (request, response) => {
    try {
      if (await handleHTTPContractRoute(request, response, observed)) {
        return;
      }
      jsonResponse(response, 404, { success: false, error: "not_found" });
    } catch (error) {
      jsonResponse(response, 500, { success: false, error: "contract_server_failed", message: error.message });
    }
  });

  server.on("upgrade", (request, socket) => {
    sockets.add(socket);
    socket.on("close", () => sockets.delete(socket));
    if (request.url !== "/api/websocket") {
      socket.destroy();
      return;
    }
    const key = request.headers["sec-websocket-key"];
    socket.write(
      [
        "HTTP/1.1 101 Switching Protocols",
        "Upgrade: websocket",
        "Connection: Upgrade",
        `Sec-WebSocket-Accept: ${websocketAcceptValue(key)}`,
        "",
        "",
      ].join("\r\n")
    );
    sendJSON(socket, { type: "auth_required", ha_version: "2026.7.0" });

    let authenticated = false;
    let pending = Buffer.alloc(0);
    socket.on("data", (chunk) => {
      pending = Buffer.concat([pending, chunk]);
      for (;;) {
        const frame = decodeFrame(pending);
        if (!frame) break;
        pending = pending.subarray(frame.consumed);
        if (frame.opcode === 0x8) {
          socket.end();
          return;
        }
        const message = JSON.parse(frame.text);
        observed.websocketMessages.push(message);
        if (!authenticated) {
          assert(message.type === "auth", "First WebSocket message must be auth");
          assert(message.access_token === WS_TOKEN, "WebSocket auth used wrong short-lived token");
          authenticated = true;
          sendJSON(socket, { type: "auth_ok", ha_version: "2026.7.0" });
          continue;
        }
        sendJSON(socket, resultForMessage(message));
      }
    });
  });

  return new Promise((resolve) => {
    server.listen(0, "127.0.0.1", () => {
      const { port } = server.address();
      resolve({ server, observed, sockets, baseURL: `http://127.0.0.1:${port}` });
    });
  });
}

function postJSON(url, body, headers = {}) {
  return new Promise((resolve, reject) => {
    const data = Buffer.from(JSON.stringify(body));
    const request = http.request(
      url,
      {
        method: "POST",
        headers: {
          "content-type": "application/json",
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

class RawWebSocketClient {
  constructor(host, port, path) {
    this.host = host;
    this.port = port;
    this.path = path;
    this.socket = null;
    this.pending = Buffer.alloc(0);
    this.messages = [];
    this.waiters = [];
  }

  connect() {
    return new Promise((resolve, reject) => {
      const key = crypto.randomBytes(16).toString("base64");
      const socket = net.createConnection({ host: this.host, port: this.port }, () => {
        socket.write(
          [
            `GET ${this.path} HTTP/1.1`,
            `Host: ${this.host}:${this.port}`,
            "Upgrade: websocket",
            "Connection: Upgrade",
            `Sec-WebSocket-Key: ${key}`,
            "Sec-WebSocket-Version: 13",
            "",
            "",
          ].join("\r\n")
        );
      });
      this.socket = socket;
      let handshake = Buffer.alloc(0);
      socket.on("data", (chunk) => {
        if (handshake !== null) {
          handshake = Buffer.concat([handshake, chunk]);
          const marker = handshake.indexOf("\r\n\r\n");
          if (marker === -1) return;
          const header = handshake.subarray(0, marker).toString("utf8");
          assert(header.includes("101 Switching Protocols"), "WebSocket handshake failed");
          this._handleData(handshake.subarray(marker + 4));
          handshake = null;
          resolve();
          return;
        }
        this._handleData(chunk);
      });
      socket.on("error", reject);
    });
  }

  _handleData(chunk) {
    this.pending = Buffer.concat([this.pending, chunk]);
    for (;;) {
      const frame = decodeFrame(this.pending);
      if (!frame) return;
      this.pending = this.pending.subarray(frame.consumed);
      const message = JSON.parse(frame.text);
      const waiter = this.waiters.shift();
      if (waiter) waiter(message);
      else this.messages.push(message);
    }
  }

  receive() {
    if (this.messages.length > 0) return Promise.resolve(this.messages.shift());
    return new Promise((resolve) => this.waiters.push(resolve));
  }

  send(value) {
    this.socket.write(encodeFrame(JSON.stringify(value), { masked: true }));
  }

  close() {
    this.socket.end();
  }
}

async function call(client, message) {
  client.send(message);
  const response = await client.receive();
  assert(response.id === message.id, `Response id mismatch for ${message.type}`);
  assert(response.success === true, `${message.type} failed: ${JSON.stringify(response.error || response)}`);
  return response.result;
}

async function run() {
  const { server, observed, sockets, baseURL } = await startContractServer();
  let client;
  try {
    const session = await postJSON(
      `${baseURL}/api/djconnect/v1/websocket/session`,
      {
        identity: { client_type: CLIENT_TYPE, client_id: DEVICE_ID, device_id: DEVICE_ID, device_name: "CI iPhone" },
        client_type: CLIENT_TYPE,
        client_id: DEVICE_ID,
        device_id: DEVICE_ID,
        device_name: "CI iPhone",
        requested_commands: routes,
      },
      { authorization: `Bearer ${DJCONNECT_TOKEN}` }
    );
    assert(session.statusCode === 200, "Session request failed");
    assert(session.body.success === true, "Session response not successful");
    assert(session.body.access_token === WS_TOKEN, "Session response token mismatch");

    const url = new URL(baseURL);
    client = new RawWebSocketClient(url.hostname, Number(url.port), "/api/websocket");
    await client.connect();
    const authRequired = await client.receive();
    assert(authRequired.type === "auth_required", "Missing auth_required");
    client.send({ type: "auth", access_token: session.body.access_token });
    const authOK = await client.receive();
    assert(authOK.type === "auth_ok", "Missing auth_ok");

    let id = 1;
    const identity = { client_type: CLIENT_TYPE, client_id: DEVICE_ID, device_id: DEVICE_ID, device_name: "CI iPhone", device_token: DJCONNECT_TOKEN };
    const baseMessage = (type, payload = {}) => ({
      id: id++,
      type,
      identity,
      payload: { identity, ...payload },
      device_id: DEVICE_ID,
      client_id: DEVICE_ID,
      client_type: CLIENT_TYPE,
      device_name: "CI iPhone",
      device_token: DJCONNECT_TOKEN,
      ...payload,
    });

    const capabilities = await call(client, baseMessage("djconnect/capabilities"));
    assert(capabilities.websocket_supported === true, "Capabilities did not advertise websocket support");
    for (const route of routes) {
      assert(capabilities.commands.includes(route), `Capabilities missing ${route}`);
    }

    assert((await call(client, baseMessage("djconnect/music_dna/profile", { music_dna_key: "contract-key", language: "nl" }))).enabled === true, "Music DNA profile failed");
    assert((await call(client, baseMessage("djconnect/music_dna/settings", { enabled: true, music_dna_key: "contract-key" }))).enabled === true, "Music DNA settings failed");
    assert((await call(client, baseMessage("djconnect/music_dna/clear", { music_dna_key: "contract-key" }))).success === true, "Music DNA clear failed");
    const exportEnvelope = await call(client, baseMessage("djconnect/music_dna/export", { music_dna_key: "contract-key" }));
    assert(exportEnvelope.format === "djconnect.music_dna.export", "Music DNA export failed");
    assert((await call(client, baseMessage("djconnect/music_dna/import", { music_dna_key: "contract-key", profile: exportEnvelope }))).generation === 10, "Music DNA import failed");
    assert((await call(client, baseMessage("djconnect/music_discovery/feed", { music_dna_key: "contract-key" }))).sections.length === 1, "Music Discovery feed failed");
    assert((await call(client, baseMessage("djconnect/music_discovery/refresh", { music_dna_key: "contract-key" }))).revision === 3, "Music Discovery refresh failed");
    assert((await call(client, baseMessage("djconnect/music_discovery/play", { discovery_item_id: "disco-1", section_id: "new_for_you" }))).success === true, "Music Discovery play failed");
    assert((await call(client, baseMessage("djconnect/music_discovery/feedback", { discovery_item_id: "disco-1", section_id: "new_for_you", feedback: "less_like_this" }))).success === true, "Music Discovery feedback failed");
    assert((await call(client, baseMessage("djconnect/track_insight"))).title === "Contract Insight", "Track Insight failed");
    assert((await call(client, baseMessage("djconnect/command", { command: "play" }))).success === true, "Command failed");
    assert((await call(client, baseMessage("djconnect/ask_dj/message", { text: "Tell me about this track" }))).text === "Contract answer", "Ask DJ message failed");
    assert((await call(client, baseMessage("djconnect/ask_dj/history", { since_revision: 0 }))).history_revision === 1, "Ask DJ history failed");
    assert((await call(client, baseMessage("djconnect/ask_dj/history/clear"))).history_revision === 1, "Ask DJ history clear failed");
    assert((await call(client, baseMessage("djconnect/ask_dj/history/state", { since_revision: 0, clear_revision: 0 }))).ask_dj_clear_required === true, "Ask DJ history state failed");
    assert((await call(client, baseMessage("djconnect/ask_dj/idle_suggestion", { music_dna_key: "contract-key" }))).assistant_message?.origin === "idle_suggestion", "Ask DJ idle suggestion failed");

    assert(observed.sessionCalls === 1, "Expected exactly one websocket session call");
    console.log(`WebSocket contract e2e passed: ${observed.websocketMessages.length} websocket messages, ${routes.length} advertised routes.`);
  } finally {
    if (client) client.close();
    for (const socket of sockets) socket.destroy();
    await new Promise((resolve) => server.close(resolve));
  }
}

module.exports = {
  RawWebSocketClient,
  assert,
  call,
  contractFixture,
  decodeFrame,
  encodeFrame,
  handleHTTPContractRoute,
  postJSON,
  resultForMessage,
  startContractServer,
};

if (require.main === module) {
  run().catch((error) => {
    console.error(`WebSocket contract e2e failed: ${error.message}`);
    process.exit(1);
  });
}
