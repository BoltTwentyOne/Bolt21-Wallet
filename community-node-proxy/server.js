/**
 * Bolt21 Community Node Proxy
 *
 * A lightweight proxy that allows Bolt21 users to route payments
 * through your Lightning node without exposing your macaroon.
 *
 * Run on your node (Raspberry Pi / MyNode / Umbrel)
 */

const https = require('https');
const http = require('http');
const fs = require('fs');
const crypto = require('crypto');

// ============================================
// CONFIGURATION - Edit these values
// ============================================

const CONFIG = {
  // Proxy server settings
  port: process.env.PROXY_PORT || 8081,
  host: '0.0.0.0',

  // Your LND REST API
  lndRestUrl: process.env.LND_REST_URL || 'https://127.0.0.1:8080',
  macaroonPath: process.env.MACAROON_PATH || '/mnt/hdd/mynode/lnd/data/chain/bitcoin/mainnet/admin.macaroon',

  // Rate limiting
  maxRequestsPerMinute: 10,
  maxRequestsPerHour: 100,

  // Optional API key (leave empty for open access)
  apiKey: process.env.API_KEY || '',

  // Fee for routing (in ppm - parts per million)
  // 0 = free, 1000 = 0.1%
  feeRatePpm: parseInt(process.env.FEE_RATE_PPM) || 0,
};

// ============================================
// RATE LIMITING
// ============================================

const rateLimits = new Map(); // IP -> { minute: [], hour: [] }

function isRateLimited(ip) {
  const now = Date.now();
  const minuteAgo = now - 60000;
  const hourAgo = now - 3600000;

  if (!rateLimits.has(ip)) {
    rateLimits.set(ip, { minute: [], hour: [] });
  }

  const limits = rateLimits.get(ip);

  // Clean old entries
  limits.minute = limits.minute.filter(t => t > minuteAgo);
  limits.hour = limits.hour.filter(t => t > hourAgo);

  // Check limits
  if (limits.minute.length >= CONFIG.maxRequestsPerMinute) {
    return { limited: true, reason: 'Too many requests per minute' };
  }
  if (limits.hour.length >= CONFIG.maxRequestsPerHour) {
    return { limited: true, reason: 'Too many requests per hour' };
  }

  // Record this request
  limits.minute.push(now);
  limits.hour.push(now);

  return { limited: false };
}

// ============================================
// LND INTERACTION
// ============================================

let macaroonHex = null;

function loadMacaroon() {
  try {
    const macaroon = fs.readFileSync(CONFIG.macaroonPath);
    macaroonHex = macaroon.toString('hex');
    console.log('[OK] Macaroon loaded');
  } catch (e) {
    console.error('[ERROR] Failed to load macaroon:', e.message);
    process.exit(1);
  }
}

function lndRequest(method, path, body = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(CONFIG.lndRestUrl + path);

    const options = {
      hostname: url.hostname,
      port: url.port || 8080,
      path: url.pathname + url.search,
      method: method,
      headers: {
        'Grpc-Metadata-macaroon': macaroonHex,
        'Content-Type': 'application/json',
      },
      rejectUnauthorized: false, // Allow self-signed certs
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const json = JSON.parse(data);
          if (res.statusCode === 200) {
            resolve(json);
          } else {
            reject(new Error(json.message || json.error || `HTTP ${res.statusCode}`));
          }
        } catch (e) {
          reject(new Error(`Invalid response: ${data.substring(0, 100)}`));
        }
      });
    });

    req.on('error', reject);
    req.setTimeout(60000, () => reject(new Error('Request timeout')));

    if (body) {
      req.write(JSON.stringify(body));
    }
    req.end();
  });
}

async function getNodeInfo() {
  return await lndRequest('GET', '/v1/getinfo');
}

async function getBalance() {
  const [wallet, channels] = await Promise.all([
    lndRequest('GET', '/v1/balance/blockchain'),
    lndRequest('GET', '/v1/balance/channels'),
  ]);

  return {
    onchain: parseInt(wallet.confirmed_balance || 0),
    spendable: parseInt(channels.local_balance?.sat || 0),
    receivable: parseInt(channels.remote_balance?.sat || 0),
  };
}

async function payInvoice(paymentRequest, amountSat = null) {
  const body = {
    payment_request: paymentRequest,
    timeout_seconds: 60,
    fee_limit: { fixed: '100' }, // Max 100 sat routing fee
  };

  if (amountSat) {
    body.amt = amountSat.toString();
  }

  const result = await lndRequest('POST', '/v1/channels/transactions', body);

  if (result.payment_error) {
    throw new Error(result.payment_error);
  }

  return {
    paymentHash: result.payment_hash,
    paymentPreimage: result.payment_preimage,
    feeSat: parseInt(result.payment_route?.total_fees || 0),
    amountSat: parseInt(result.payment_route?.total_amt || 0),
  };
}

async function createInvoice(amountSat, memo = '') {
  const result = await lndRequest('POST', '/v1/invoices', {
    value: amountSat.toString(),
    memo: memo,
    expiry: '3600',
  });

  return {
    paymentRequest: result.payment_request,
    paymentHash: result.r_hash,
  };
}

async function decodeInvoice(paymentRequest) {
  return await lndRequest('GET', `/v1/payreq/${paymentRequest}`);
}

// ============================================
// HTTP SERVER
// ============================================

function parseBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', chunk => {
      body += chunk;
      if (body.length > 10000) {
        reject(new Error('Body too large'));
      }
    });
    req.on('end', () => {
      try {
        resolve(body ? JSON.parse(body) : {});
      } catch (e) {
        reject(new Error('Invalid JSON'));
      }
    });
  });
}

function sendJson(res, status, data) {
  res.writeHead(status, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, X-API-Key',
  });
  res.end(JSON.stringify(data));
}

function getClientIp(req) {
  return req.headers['x-forwarded-for']?.split(',')[0] ||
         req.socket.remoteAddress ||
         'unknown';
}

async function handleRequest(req, res) {
  const ip = getClientIp(req);
  const url = new URL(req.url, `http://${req.headers.host}`);
  const path = url.pathname;

  // CORS preflight
  if (req.method === 'OPTIONS') {
    sendJson(res, 200, { ok: true });
    return;
  }

  // API key check (if configured)
  if (CONFIG.apiKey && req.headers['x-api-key'] !== CONFIG.apiKey) {
    sendJson(res, 401, { error: 'Invalid API key' });
    return;
  }

  // Rate limiting
  const rateCheck = isRateLimited(ip);
  if (rateCheck.limited) {
    sendJson(res, 429, { error: rateCheck.reason });
    return;
  }

  try {
    // Routes
    if (path === '/status' && req.method === 'GET') {
      const info = await getNodeInfo();
      const balance = await getBalance();
      sendJson(res, 200, {
        online: true,
        alias: info.alias,
        channels: info.num_active_channels,
        spendable: balance.spendable,
        receivable: balance.receivable,
        feeRatePpm: CONFIG.feeRatePpm,
      });

    } else if (path === '/pay' && req.method === 'POST') {
      const body = await parseBody(req);

      if (!body.invoice) {
        sendJson(res, 400, { error: 'Missing invoice' });
        return;
      }

      // Decode invoice to check amount
      const decoded = await decodeInvoice(body.invoice);
      const amountSat = parseInt(decoded.num_satoshis || 0) || body.amount;

      if (!amountSat || amountSat <= 0) {
        sendJson(res, 400, { error: 'Invalid amount' });
        return;
      }

      // Apply fee if configured
      let totalAmount = amountSat;
      let proxyFee = 0;
      if (CONFIG.feeRatePpm > 0) {
        proxyFee = Math.ceil(amountSat * CONFIG.feeRatePpm / 1000000);
        // Note: User would need to pay proxy fee separately or we deduct from balance
      }

      console.log(`[PAY] ${ip} -> ${amountSat} sats`);

      const result = await payInvoice(body.invoice, decoded.num_satoshis ? null : body.amount);

      sendJson(res, 200, {
        success: true,
        paymentHash: result.paymentHash,
        feeSat: result.feeSat,
        amountSat: result.amountSat,
      });

    } else if (path === '/invoice' && req.method === 'POST') {
      const body = await parseBody(req);

      if (!body.amount || body.amount <= 0) {
        sendJson(res, 400, { error: 'Invalid amount' });
        return;
      }

      console.log(`[INVOICE] ${ip} -> ${body.amount} sats`);

      const result = await createInvoice(body.amount, body.memo || 'Bolt21');

      sendJson(res, 200, {
        invoice: result.paymentRequest,
        paymentHash: result.paymentHash,
      });

    } else {
      sendJson(res, 404, { error: 'Not found' });
    }

  } catch (e) {
    console.error(`[ERROR] ${path}:`, e.message);
    sendJson(res, 500, { error: e.message });
  }
}

// ============================================
// STARTUP
// ============================================

async function main() {
  console.log('========================================');
  console.log('  Bolt21 Community Node Proxy');
  console.log('========================================');

  loadMacaroon();

  // Test LND connection
  try {
    const info = await getNodeInfo();
    console.log(`[OK] Connected to: ${info.alias}`);
    console.log(`[OK] Channels: ${info.num_active_channels}`);
  } catch (e) {
    console.error('[ERROR] Cannot connect to LND:', e.message);
    process.exit(1);
  }

  // Start server
  const server = http.createServer(handleRequest);

  server.listen(CONFIG.port, CONFIG.host, () => {
    console.log(`[OK] Proxy running on http://${CONFIG.host}:${CONFIG.port}`);
    console.log('');
    console.log('Endpoints:');
    console.log('  GET  /status  - Node status');
    console.log('  POST /pay     - Pay invoice');
    console.log('  POST /invoice - Create invoice');
    console.log('========================================');
  });
}

main().catch(console.error);
