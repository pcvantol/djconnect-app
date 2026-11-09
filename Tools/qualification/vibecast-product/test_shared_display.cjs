const assert = require('node:assert/strict');
const { webkit } = require('playwright');

const displayPath = '/djconnect/vibecast/display';
const apiPath = '/api/djconnect/v1/display/';
const token = 'djcd_' + 'A'.repeat(43);
const binding = {
  issuer_epoch: 'fixture-epoch',
  display_id: 'fixture-display',
  share_id: 'fixture-share',
  share_generation: 1,
  session_id: 'fixture-session',
};
const redCover = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAIAAAD8GO2jAAAANUlEQVR4nO3QsQ0AMAzDsLT//9yeoCkbeYAN6LzZdZf3x0GSKEmUJEoSJYmSREmiJFGSaMoHo8QBPwYSAhsAAAAASUVORK5CYII=',
  'base64',
);
const blueCover = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAIAAAD8GO2jAAAAN0lEQVR4nO3RMQ0AMAzEQLf8OacQ3CWbD8BHcg4Mm+7qOh340A9UiVSJVIlUiVSJVIlUiVSJMA+hxgE/8m7SpQAAAABJRU5ErkJggg==',
  'base64',
);

async function main() {
  const origin = new URL(process.env.DJCONNECT_VIBECAST_TEST_ORIGIN);
  assert.equal(origin.href, origin.origin + '/');
  assert.equal(origin.protocol, 'https:');
  const displayURL = origin.origin + displayPath;
  // Fetch only the public document. Every browser request below is intercepted.
  const response = await fetch(displayURL, {
    headers: { 'ngrok-skip-browser-warning': '1' },
    redirect: 'error',
    signal: AbortSignal.timeout(15000),
  });
  assert.equal(response.status, 200);
  const csp = response.headers.get('content-security-policy');
  assert.match(csp ?? '', /frame-ancestors 'none'/);
  assert.match(response.headers.get('cache-control') ?? '', /no-store/);
  const html = await response.text();
  const executablePath = process.env.DJCONNECT_VIBECAST_WEBKIT_EXECUTABLE;
  const browser = await webkit.launch(executablePath ? { executablePath } : {});
  try {
    const page = await browser.newPage({ serviceWorkers: 'block' });
    const unexpected = [];
    let approved = false;
    let artworkRequests = 0;
    page.on('pageerror', error => unexpected.push(error.message));

    await page.route(/^https?:\/\//, async route => {
      const request = route.request();
      const url = new URL(request.url());
      if (url.href === displayURL && request.method() === 'GET') {
        return route.fulfill({ body: html, contentType: 'text/html', headers: { 'Content-Security-Policy': csp } });
      }
      if (url.origin === origin.origin && request.method() === 'POST') {
        const reply = data => route.fulfill({ json: { success: true, ...data } });
        switch (url.pathname) {
          case apiPath + 'claim':
            return reply({
              contract_version: 1, code: '123456', expires_in: 120, issuer_epoch: binding.issuer_epoch,
              claim_id: 'fixture-claim', claim_secret: 'fixture-secret', browser_generation: 'fixture-generation',
            });
          case apiPath + 'collect':
            if (!approved) return reply({ state: 'pending' });
            return reply({
              ...binding, state: 'admitted', grant_token: token, lease_expires_in: 60,
              capabilities: { owner_controls: false, session_end: false },
            });
          case apiPath + 'artwork': {
            artworkRequests += 1;
            const { reference } = request.postDataJSON();
            const cover = reference === 'a'.repeat(64) ? redCover : reference === 'b'.repeat(64) ? blueCover : null;
            if (request.headers().authorization === 'Bearer ' + token && cover) {
              return route.fulfill({
                body: cover, contentType: 'image/png', headers: { 'Content-Length': String(cover.length) },
              });
            }
            break;
          }
        }
      }
      unexpected.push('Unexpected browser request');
      return route.abort();
    });

    const socketURL = 'wss://' + origin.host + apiPath + 'live';
    const authenticated = Promise.withResolvers();
    await page.routeWebSocket(/.*/, socket => {
      if (socket.url() !== socketURL) {
        unexpected.push('Unexpected WebSocket request');
        return socket.close();
      }
      socket.onMessage(data => {
        const request = JSON.parse(data);
        if (request.type === 'authenticate' && request.grant_token === token) {
          authenticated.resolve(socket);
        }
      });
    });

    await page.goto(displayURL, { timeout: 15000 });
    await page.waitForFunction(
      () => document.querySelector('#handoff strong')?.textContent === '123456',
      null,
      { timeout: 10000 },
    );
    approved = true;
    let timer;
    const socket = await Promise.race([
      authenticated.promise,
      new Promise((_, reject) => {
        timer = setTimeout(() => reject(new Error('Display never authenticated')), 10000);
      }),
    ]).finally(() => clearTimeout(timer));

    const deadline = new Date(Date.now() + 30000).toISOString();
    const contributions = ['First public contribution', 'Second public contribution', 'Third public contribution'];
    const sharedFlow = contributions.map((content, index) => ({
      moment_id: 'fixture-moment-' + index,
      type: 'music_announcement',
      content,
      display_expires_at: deadline,
    }));
    const publish = (item, reference) => socket.send(JSON.stringify({
      type: 'snapshot', contract_version: 1, connection_generation: 1,
      snapshot: {
        ...binding, contract_version: 1,
        session: { session_id: binding.session_id, runtime_state: 'active', locale: 'en' },
        playback: { state: 'playing', item_id: item, title: item, album: 'Fixture album' },
        shared_flow: sharedFlow,
        dj_moments: [{ moment_id: 'fixture-private', content: 'PRIVATE-FIXTURE-CANARY' }],
        artwork: { item_id: item, reference: reference.repeat(64), expires_at: deadline },
      },
    }));
    const waitForCover = expected => page.waitForFunction(rgb => {
      const image = document.querySelector('#artwork');
      if (image.hidden || !image.complete || !image.naturalWidth) return false;
      const ctx = document.createElement('canvas').getContext('2d');
      ctx.drawImage(image, 0, 0);
      return Array.from(ctx.getImageData(0, 0, 1, 1).data).slice(0, 3).join(',') === rgb;
    }, expected, { timeout: 10000 });

    publish('Fixture track A', 'a');
    await waitForCover('255,0,0').catch(async error => {
      const state = await page.locator('#state').textContent();
      throw new Error(`First cover missing (display state: ${state}, artwork requests: ${artworkRequests}, browser errors: ${unexpected.join(', ')})`, { cause: error });
    });
    assert.equal(await page.locator('#title').textContent(), 'Fixture track A');
    assert.deepEqual(await page.locator('#flow-cards li p').allTextContents(), contributions);
    assert.match(await page.locator('#flow-cards li').last().getAttribute('class'), /flow-age-0/);
    assert.equal(await page.getByText('PRIVATE-FIXTURE-CANARY', { exact: true }).count(), 0);

    publish('Fixture track B', 'b');
    await waitForCover('0,0,255');
    assert.equal(await page.locator('#title').textContent(), 'Fixture track B');
    assert.deepEqual(await page.locator('#flow-cards li p').allTextContents(), contributions);

    await socket.close({ code: 1008 });
    await page.locator('#artwork').waitFor({ state: 'hidden', timeout: 10000 });
    assert.equal(await page.locator('#artwork').getAttribute('src'), null);
    assert.equal(await page.locator('#flow-cards li').count(), 0);
    assert.deepEqual(unexpected, []);
    console.log('VibeCast display: claim, shared flow order, private canary exclusion, artwork change and withdrawal passed.');
  } finally {
    await browser.close();
  }
}

main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
