const express  = require('express');
const cors     = require('cors');
const { execSync } = require('child_process');
const fs    = require('fs');
const path  = require('path');
const os    = require('os');
const https = require('https');
const http  = require('http');

const app  = express();
const PORT = 3002;

app.use(cors({ origin: 'http://localhost:3001' }));
app.use(express.json());

// ── Config ─────────────────────────────────────────────────────────────────────
const APICTL          = process.env.APICTL_PATH       || '/Users/ramindu/wso2/apictl/apictl';
const WORK_DIR        = process.env.APICTL_WORK_DIR   || path.join(__dirname); // script dir = server/
const ENVIRONMENT     = process.env.APICTL_ENV        || 'Production';
const ADMIN_USER      = process.env.APICTL_ADMIN_USER || 'admin';
const ADMIN_PASS      = process.env.APICTL_ADMIN_PASS || 'admin';
const AZURE_APIS_DIR  = process.env.AZURE_APIS_DIR    || '/Users/ramindu/Desktop/AzureAPis';

// ── DevPortal proxy config ─────────────────────────────────────────────────────
const APIM_BASE     = process.env.APIM_BASE     || 'https://cp.wso2.com';
const DP_USER       = process.env.DP_USER       || 'admin';
const DP_PASS       = process.env.DP_PASS       || 'admin';
const DP_CLIENT_ID     = process.env.DP_CLIENT_ID     || 'cip9BfLH2SdYawxR6mV8JwF_tNka';
const DP_CLIENT_SECRET = process.env.DP_CLIENT_SECRET || 'fVXTk9WIHgrSEfRdjkHuPXgBWDIa';
const DP_SCOPES     = 'apim:subscribe apim:app_manage apim:api_view apim:subscribe_scope';

// Token cache: { accessToken, expiresAt }
let dpTokenCache = null;

// Low-level HTTPS/HTTP request (no external deps)
function rawRequest(method, urlStr, headers, bodyStr) {
  return new Promise((resolve, reject) => {
    const u    = new URL(urlStr);
    const lib  = u.protocol === 'https:' ? https : http;
    const body = bodyStr ? Buffer.from(bodyStr, 'utf8') : null;
    const opts = {
      hostname:           u.hostname,
      port:               u.port || (u.protocol === 'https:' ? 443 : 80),
      path:               u.pathname + u.search,
      method,
      headers:            { ...headers, ...(body ? { 'Content-Length': body.length } : {}) },
      rejectUnauthorized: false,
    };
    const req = lib.request(opts, (res) => {
      const chunks = [];
      res.on('data',  c  => chunks.push(c));
      res.on('end',   () => resolve({ status: res.statusCode, headers: res.headers, body: Buffer.concat(chunks).toString('utf8') }));
    });
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

// Password grant using pre-configured client credentials
async function fetchToken() {
  if (!DP_CLIENT_ID || !DP_CLIENT_SECRET) {
    throw new Error(
      'DP_CLIENT_ID and DP_CLIENT_SECRET env vars are required.\n' +
      'Create an OAuth2 app in the APIM DevPortal, generate keys, then:\n' +
      '  DP_CLIENT_ID=<id> DP_CLIENT_SECRET=<secret> node index.js'
    );
  }
  const basicAuth = Buffer.from(`${DP_CLIENT_ID}:${DP_CLIENT_SECRET}`).toString('base64');
  const body = new URLSearchParams({
    grant_type: 'password',
    username:   DP_USER,
    password:   DP_PASS,
    scope:      DP_SCOPES,
  }).toString();
  const res = await rawRequest('POST', `${APIM_BASE}/oauth2/token`, {
    'Authorization': `Basic ${basicAuth}`,
    'Content-Type':  'application/x-www-form-urlencoded',
  }, body);
  if (res.status !== 200) throw new Error(`Token request failed (${res.status}): ${res.body}`);
  const data = JSON.parse(res.body);
  return { accessToken: data.access_token, expiresIn: data.expires_in };
}

// Returns a valid Bearer token, refreshing when within 60s of expiry
async function getDevPortalToken() {
  const now = Date.now();
  if (dpTokenCache && dpTokenCache.expiresAt - now > 60_000) {
    return dpTokenCache.accessToken;
  }
  const { accessToken, expiresIn } = await fetchToken();
  dpTokenCache = { accessToken, expiresAt: now + expiresIn * 1000 };
  console.log(`[devportal] Token acquired for ${DP_USER}, expires in ${expiresIn}s`);
  return accessToken;
}

function run(cmd, cwd) {
  return execSync(cmd, {
    cwd: cwd || WORK_DIR,
    encoding: 'utf8',
    env: { ...process.env, PATH: `${path.dirname(APICTL)}:${process.env.PATH}` },
    timeout: 120000,
    stdio: ['pipe', 'pipe', 'pipe'],
  }).trim();
}

// Find the extracted API directory — mirrors shell script fallback logic
function findApiDir(apiName, apiVersion) {
  const candidates = [
    path.join(WORK_DIR, `${apiName}-${apiVersion}`),
    path.join(WORK_DIR, `${apiName}_${apiVersion}`),
    path.join(WORK_DIR, apiName),
  ];
  for (const c of candidates) {
    if (fs.existsSync(c)) return c;
  }
  // glob fallback
  const entries = fs.readdirSync(WORK_DIR).filter(
    e => e.startsWith(apiName) && fs.statSync(path.join(WORK_DIR, e)).isDirectory()
  );
  if (entries.length) return path.join(WORK_DIR, entries[0]);
  return null;
}

// ── GET|POST /api/devportal/* — proxy to APIM DevPortal v3 ────────────────────
app.all('/api/devportal/*', async (req, res) => {
  const subPath = req.path.replace(/^\/api\/devportal/, '');
  const qs      = Object.keys(req.query).length
    ? '?' + new URLSearchParams(req.query).toString()
    : '';
  const target  = `${APIM_BASE}/api/am/devportal/v3${subPath}${qs}`;

  try {
    const token   = await getDevPortalToken();
    const headers = { Authorization: `Bearer ${token}`, Accept: 'application/json' };

    let bodyStr = null;
    if (req.method !== 'GET' && req.method !== 'HEAD') {
      bodyStr = JSON.stringify(req.body);
      headers['Content-Type'] = 'application/json';
    }

    const result = await rawRequest(req.method, target, headers, bodyStr);
    if (result.headers['content-type']) res.setHeader('Content-Type', result.headers['content-type']);
    res.status(result.status).send(result.body);
  } catch (e) {
    console.error('[devportal proxy]', e.message);
    res.status(500).json({ error: e.message });
  }
});

// ── GET /api/migrate/apis — list ZIPs/folders in AZURE_APIS_DIR ───────────────
app.get('/api/migrate/apis', (_req, res) => {
  try {
    if (!fs.existsSync(AZURE_APIS_DIR)) {
      return res.json({ apis: [], error: `Directory not found: ${AZURE_APIS_DIR}` });
    }
    const entries = fs.readdirSync(AZURE_APIS_DIR).filter(e => {
      const full = path.join(AZURE_APIS_DIR, e);
      return e.endsWith('.zip') || fs.statSync(full).isDirectory();
    });
    const apis = entries.map(e => {
      const base = e.replace(/\.zip$/i, '');
      const m = base.match(/^(.+)[_-](\d+\.\d+\.\d+)$/);
      return m
        ? { name: m[1], version: m[2], file: e }
        : { name: base, version: '', file: e };
    });
    res.json({ apis });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ── POST /api/migrate ──────────────────────────────────────────────────────────
app.post('/api/migrate', (req, res) => {
  const { apiName, version, step } = req.body;
  if (!apiName || !version) return res.status(400).json({ error: 'apiName and version are required' });

  const steps  = [];

  const doStep = (label, fn) => {
    try {
      const out = fn();
      steps.push({ step: label, status: 'success', output: out || '(done)' });
      return true;
    } catch (e) {
      const msg = (e.stderr || e.stdout || e.message || String(e)).toString().trim();
      steps.push({ step: label, status: 'error', output: msg });
      return false;
    }
  };

  // ── Step 1: Extract & patch api.json + copy deployment yaml ─────────────────
  if (step === 'prepare' || step === 'all') {
    const ok = doStep('Extract & patch api.json', () => {
      const zipCandidates = [
        path.join(AZURE_APIS_DIR, `${apiName}_${version}.zip`),
        path.join(AZURE_APIS_DIR, `${apiName}-${version}.zip`),
      ];

      const zipSrc = zipCandidates.find(f => fs.existsSync(f));
      if (!zipSrc) throw new Error(
        `ZIP not found in ${AZURE_APIS_DIR}. Looked for:\n  ${zipCandidates.map(p => path.basename(p)).join('\n  ')}`
      );

      // Clean up old extract
      const apiDir = path.join(WORK_DIR, `${apiName}-${version}`);
      if (fs.existsSync(apiDir)) fs.rmSync(apiDir, { recursive: true });

      run(`unzip -o -q "${zipSrc}" -d "${WORK_DIR}"`);

      const extractedDir = findApiDir(apiName, version);
      if (!extractedDir) throw new Error('Could not find extracted API directory');

      // Patch api.json — fields are nested under .data
      const apiJsonPath = path.join(extractedDir, 'api.json');
      if (!fs.existsSync(apiJsonPath)) throw new Error(`api.json not found at ${apiJsonPath}`);

      const raw = JSON.parse(fs.readFileSync(apiJsonPath, 'utf8'));
      if (!raw.data) throw new Error('api.json has no .data field');
      raw.data.gatewayVendor        = 'wso2';
      raw.data.gatewayType          = 'wso2/apk';
      raw.data.initiatedFromGateway = false;
      fs.writeFileSync(apiJsonPath, JSON.stringify(raw, null, 2));

      // Copy deployment_environments.yaml from server/ dir
      const deployYaml = path.join(__dirname, 'deployment_environments.yaml');
      if (fs.existsSync(deployYaml)) {
        fs.copyFileSync(deployYaml, path.join(extractedDir, 'deployment_environments.yaml'));
        return `api.json patched + deployment_environments.yaml copied\nSource: ${zipSrc}\nExtracted: ${extractedDir}`;
      }
      return `api.json patched\nSource: ${zipSrc}\nExtracted: ${extractedDir}`;
    });
    if (!ok && step === 'all') return res.json({ success: false, steps });
  }

  // ── Step 2: Delete existing API (admin) ─────────────────────────────────────
  if (step === 'delete' || step === 'all') {
    const ok = doStep('Login (admin) & Delete existing API', () => {
      run(`"${APICTL}" login ${ENVIRONMENT} -u ${ADMIN_USER} -p "${ADMIN_PASS}" -k`);
      return run(`"${APICTL}" delete api -n ${apiName} -v ${version} -r ${ADMIN_USER} -e ${ENVIRONMENT} -k`);
    });
    if (!ok && step === 'all') return res.json({ success: false, steps });
  }

  // ── Step 3: Import ───────────────────────────────────────────────────────────
  if (step === 'import' || step === 'all') {
    doStep('Import updated API', () => {
      run(`"${APICTL}" login ${ENVIRONMENT} -u ${ADMIN_USER} -p "${ADMIN_PASS}" -k`);
      const extractedDir = findApiDir(apiName, version);
      if (!extractedDir) throw new Error('Cannot find extracted API directory — run prepare step first');
      return run(`"${APICTL}" import api -f "${extractedDir}" -e ${ENVIRONMENT} --update -k --preserve-provider=false --verbose`);
    });
  }

  const success = steps.every(s => s.status === 'success');
  res.json({ success, steps });
});

// ── GET /api/migrate/config ────────────────────────────────────────────────────
app.get('/api/migrate/config', (_req, res) => {
  res.json({
    APICTL_ENV:         ENVIRONMENT,
    APICTL_DEVOPS_USER: DEVOPS_USER,
    APICTL_ADMIN_USER:  ADMIN_USER,
    APICTL_PATH:        APICTL,
    APICTL_WORK_DIR:    WORK_DIR,
    APICTL_EXPORT_BASE: APICTL_EXPORT_BASE,
    deploymentYaml:     path.join(__dirname, 'deployment_environments.yaml'),
  });
});

app.listen(PORT, () => {
  console.log(`Migration server on http://localhost:${PORT}`);
  console.log(`  APICTL:      ${APICTL}`);
  console.log(`  Environment: ${ENVIRONMENT}`);
  console.log(`  Export dir:  ${path.join(APICTL_EXPORT_BASE, ENVIRONMENT)}`);
  console.log(`  Work dir:    ${WORK_DIR}`);
});
