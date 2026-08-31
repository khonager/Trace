import { createHmac, timingSafeEqual } from 'node:crypto';
import { promises as dns } from 'node:dns';
import { createServer } from 'node:http';
import { isIP } from 'node:net';

const port = Number.parseInt(process.env.PORT ?? '8787', 10);
const braveApiKey = process.env.BRAVE_SEARCH_API_KEY ?? '';
const proxySecret = process.env.MEDIA_PROXY_SECRET ?? '';
const allowedOrigins = new Set(
  (process.env.ALLOWED_ORIGINS ?? '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean),
);
const maxMediaBytes = 25 * 1024 * 1024;
const rateWindows = new Map();

if (!braveApiKey || !proxySecret) {
  throw new Error(
    'BRAVE_SEARCH_API_KEY and MEDIA_PROXY_SECRET must both be configured.',
  );
}

createServer(async (request, response) => {
  try {
    setCors(request, response);
    if (request.method === 'OPTIONS') {
      response.writeHead(204).end();
      return;
    }
    if (request.method !== 'GET') return json(response, 405, { error: 'Method not allowed.' });
    if (!withinRateLimit(request.socket.remoteAddress ?? 'unknown')) {
      return json(response, 429, { error: 'Too many requests. Try again shortly.' });
    }

    const requestUrl = new URL(request.url ?? '/', 'http://relay.local');
    if (requestUrl.pathname === '/health') return json(response, 200, { ok: true });
    if (requestUrl.pathname === '/v1/media/search') {
      return await search(requestUrl, response);
    }
    if (requestUrl.pathname === '/v1/media/fetch') {
      return await fetchSignedMedia(requestUrl, response);
    }
    return json(response, 404, { error: 'Not found.' });
  } catch (error) {
    console.error(error instanceof Error ? error.message : error);
    if (!response.headersSent) json(response, 500, { error: 'Media relay failed.' });
    else response.destroy();
  }
}).listen(port, () => console.log(`Trace media-search relay listening on ${port}`));

async function search(requestUrl, response) {
  const query = requestUrl.searchParams.get('q')?.trim() ?? '';
  const kind = requestUrl.searchParams.get('kind') ?? 'gif';
  const safety = requestUrl.searchParams.get('safety') === 'strict' ? 'strict' : 'off';
  if (!query || query.length > 200) return json(response, 400, { error: 'Invalid query.' });
  if (kind !== 'gif' && kind !== 'sticker') {
    return json(response, 400, { error: 'Invalid media kind.' });
  }

  // Brave has no documented GIF-only parameter. The search operator narrows
  // the index; extension/MIME checks below enforce the actual media type.
  const braveQuery = kind === 'gif'
    ? `${query} filetype:gif`
    : `${query} transparent sticker filetype:png`;
  const upstreamUrl = new URL('https://api.search.brave.com/res/v1/images/search');
  upstreamUrl.searchParams.set('q', braveQuery);
  upstreamUrl.searchParams.set('count', '80');
  upstreamUrl.searchParams.set('safesearch', safety);
  upstreamUrl.searchParams.set('spellcheck', 'true');
  const upstream = await fetch(upstreamUrl, {
    headers: {
      Accept: 'application/json',
      'X-Subscription-Token': braveApiKey,
    },
    signal: AbortSignal.timeout(15_000),
  });
  if (!upstream.ok) {
    console.error(`Brave search failed: ${upstream.status}`);
    return json(response, 502, { error: 'Open-web search is unavailable.' });
  }
  const payload = await upstream.json();
  const results = (Array.isArray(payload.results) ? payload.results : [])
    .map((item, index) => mapBraveResult(item, index, kind))
    .filter(Boolean)
    .slice(0, 48);
  return json(response, 200, { results });
}

function mapBraveResult(item, index, kind) {
  const original = stringUrl(item?.properties?.url);
  const thumbnail = stringUrl(item?.thumbnail?.src) ?? original;
  if (!original || !thumbnail) return null;
  const originalPath = new URL(original).pathname.toLowerCase();
  const format = String(item?.properties?.format ?? '').toLowerCase();
  const isGif = format === 'gif' || originalPath.endsWith('.gif');
  const isPng = format === 'png' || originalPath.endsWith('.png');
  if (kind === 'gif' ? !isGif : !isPng) return null;
  return {
    id: `brave-${index}-${createHmac('sha256', proxySecret).update(original).digest('hex').slice(0, 12)}`,
    title: String(item?.title ?? 'Web media').slice(0, 200),
    previewUrl: signedFetchUrl(thumbnail, 15 * 60),
    downloadUrl: signedFetchUrl(original, 15 * 60),
    mimeType: isGif ? 'image/gif' : 'image/png',
    source: 'Brave',
    width: integer(item?.properties?.width),
    height: integer(item?.properties?.height),
  };
}

function signedFetchUrl(sourceUrl, lifetimeSeconds) {
  const expires = Math.floor(Date.now() / 1000) + lifetimeSeconds;
  const signature = sign(sourceUrl, expires);
  const result = new URL('/v1/media/fetch', publicBaseUrl());
  result.searchParams.set('url', sourceUrl);
  result.searchParams.set('expires', String(expires));
  result.searchParams.set('signature', signature);
  return result.toString();
}

async function fetchSignedMedia(requestUrl, response) {
  const sourceUrl = requestUrl.searchParams.get('url') ?? '';
  const expires = Number.parseInt(requestUrl.searchParams.get('expires') ?? '', 10);
  const suppliedSignature = requestUrl.searchParams.get('signature') ?? '';
  if (!sourceUrl || !Number.isFinite(expires) || expires < Date.now() / 1000) {
    return json(response, 403, { error: 'Media link expired.' });
  }
  const expectedSignature = sign(sourceUrl, expires);
  if (!safeEqual(suppliedSignature, expectedSignature)) {
    return json(response, 403, { error: 'Invalid media link.' });
  }
  const upstream = await fetchPublic(sourceUrl);
  if (!upstream.ok) return json(response, 502, { error: 'Media download failed.' });
  const contentType = (upstream.headers.get('content-type') ?? '').split(';')[0].toLowerCase();
  if (!['image/gif', 'image/png', 'image/webp', 'image/jpeg', 'video/mp4'].includes(contentType)) {
    return json(response, 415, { error: 'Unsupported media type.' });
  }
  const declaredLength = Number.parseInt(upstream.headers.get('content-length') ?? '0', 10);
  if (declaredLength > maxMediaBytes) return json(response, 413, { error: 'Media is too large.' });
  const bytes = Buffer.from(await upstream.arrayBuffer());
  if (bytes.length > maxMediaBytes) return json(response, 413, { error: 'Media is too large.' });
  response.writeHead(200, {
    'Cache-Control': 'private, max-age=300',
    'Content-Length': bytes.length,
    'Content-Type': contentType,
    'X-Content-Type-Options': 'nosniff',
  });
  response.end(bytes);
}

async function fetchPublic(initialUrl) {
  let current = new URL(initialUrl);
  for (let redirects = 0; redirects <= 3; redirects += 1) {
    await assertPublicUrl(current);
    const result = await fetch(current, { redirect: 'manual', signal: AbortSignal.timeout(20_000) });
    if (![301, 302, 303, 307, 308].includes(result.status)) return result;
    const location = result.headers.get('location');
    if (!location) return result;
    current = new URL(location, current);
  }
  throw new Error('Too many media redirects.');
}

async function assertPublicUrl(url) {
  if (url.protocol !== 'https:') throw new Error('Only HTTPS media is allowed.');
  const addresses = await dns.lookup(url.hostname, { all: true, verbatim: true });
  if (!addresses.length || addresses.some(({ address }) => isPrivateAddress(address))) {
    throw new Error('Private network media is blocked.');
  }
}

function isPrivateAddress(address) {
  if (isIP(address) === 4) {
    const [a, b] = address.split('.').map(Number);
    return a === 10 || a === 127 || a === 0 || (a === 169 && b === 254) ||
      (a === 172 && b >= 16 && b <= 31) || (a === 192 && b === 168);
  }
  const normalized = address.toLowerCase();
  return normalized === '::1' || normalized === '::' || normalized.startsWith('fc') ||
    normalized.startsWith('fd') || normalized.startsWith('fe8') ||
    normalized.startsWith('fe9') || normalized.startsWith('fea') ||
    normalized.startsWith('feb') || normalized.startsWith('::ffff:127.') ||
    normalized.startsWith('::ffff:10.') || normalized.startsWith('::ffff:192.168.');
}

function sign(sourceUrl, expires) {
  return createHmac('sha256', proxySecret).update(`${expires}\n${sourceUrl}`).digest('base64url');
}

function safeEqual(left, right) {
  const leftBytes = Buffer.from(left);
  const rightBytes = Buffer.from(right);
  return leftBytes.length === rightBytes.length && timingSafeEqual(leftBytes, rightBytes);
}

function withinRateLimit(key) {
  const now = Date.now();
  const current = rateWindows.get(key);
  if (!current || now - current.startedAt >= 60_000) {
    rateWindows.set(key, { startedAt: now, count: 1 });
    return true;
  }
  current.count += 1;
  return current.count <= 60;
}

function setCors(request, response) {
  const origin = request.headers.origin;
  if (origin && allowedOrigins.has(origin)) {
    response.setHeader('Access-Control-Allow-Origin', origin);
    response.setHeader('Vary', 'Origin');
  }
  response.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  response.setHeader('Access-Control-Allow-Headers', 'Content-Type');
}

function json(response, status, value) {
  const body = JSON.stringify(value);
  response.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
    'Cache-Control': 'no-store',
    'X-Content-Type-Options': 'nosniff',
  });
  response.end(body);
}

function stringUrl(value) {
  try {
    const parsed = new URL(String(value ?? ''));
    return parsed.protocol === 'https:' ? parsed.toString() : null;
  } catch {
    return null;
  }
}

function integer(value) {
  const result = Number.parseInt(String(value ?? ''), 10);
  return Number.isFinite(result) ? result : null;
}

function publicBaseUrl() {
  const configured = process.env.PUBLIC_BASE_URL;
  if (!configured) throw new Error('PUBLIC_BASE_URL must be configured.');
  return configured;
}
