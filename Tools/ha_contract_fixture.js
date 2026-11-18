#!/usr/bin/env node
"use strict";

const {
  RawWebSocketClient,
  assert,
  call,
  contractFixture,
  decodeFrame,
  encodeFrame,
  postJSON,
  resultForMessage,
  startContractServer,
} = require("./websocket_e2e_contract");

module.exports = {
  RawWebSocketClient,
  assert,
  call,
  contractFixture,
  decodeFrame,
  encodeFrame,
  postJSON,
  resultForMessage,
  startContractServer,
};

if (require.main === module) {
  startContractServer()
    .then(({ baseURL }) => {
      console.log(`DJConnect HA contract fixture listening at ${baseURL}`);
      console.log("Press Ctrl-C to stop.");
    })
    .catch((error) => {
      console.error(`DJConnect HA contract fixture failed: ${error.message}`);
      process.exit(1);
    });
}
