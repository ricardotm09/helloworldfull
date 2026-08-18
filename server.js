const http = require('http');
const fs = require('fs');
const path = require('path');
const client = require('prom-client');

let clickCount = 0;

const register = new client.Registry();
client.collectDefaultMetrics({
  register,
  prefix: 'click_counter_'
});

const httpRequestsTotal = new client.Counter({
  name: 'click_counter_http_requests_total',
  help: 'Total number of HTTP requests handled by the app',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register]
});

const httpRequestDurationSeconds = new client.Histogram({
  name: 'click_counter_http_request_duration_seconds',
  help: 'Request duration in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.01, 0.05, 0.1, 0.3, 0.5, 1, 2, 5],
  registers: [register]
});

const clickEventsTotal = new client.Counter({
  name: 'click_counter_click_events_total',
  help: 'Total number of click events received by POST /count',
  registers: [register]
});

function routeLabel(method, pathName) {
  if (method === 'POST' && pathName === '/count') {
    return '/count';
  }

  if (method === 'GET' && (pathName === '/health' || pathName === '/health/ready')) {
    return '/health/ready';
  }

  if (method === 'GET' && pathName === '/health/live') {
    return '/health/live';
  }

  if (method === 'GET' && pathName === '/metrics') {
    return '/metrics';
  }

  return '/';
}

function observeRequest(method, route, statusCode, startTimeNs) {
  const durationSeconds = Number(process.hrtime.bigint() - startTimeNs) / 1e9;
  const statusLabel = String(statusCode);

  httpRequestsTotal.inc({ method, route, status_code: statusLabel });
  httpRequestDurationSeconds.observe({ method, route, status_code: statusLabel }, durationSeconds);
}

const server = http.createServer(async (req, res) => {
  const startTimeNs = process.hrtime.bigint();
  const pathName = req.url.split('?')[0];
  const route = routeLabel(req.method, pathName);

  if (pathName === '/count' && req.method === 'POST') {
    clickCount += 1;
    clickEventsTotal.inc();

    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ count: clickCount }));
    observeRequest(req.method, route, 200, startTimeNs);
    return;
  }

  if (pathName === '/health' || pathName === '/health/ready') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok', check: 'ready' }));
    observeRequest(req.method, route, 200, startTimeNs);
    return;
  }

  if (pathName === '/health/live') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok', check: 'live' }));
    observeRequest(req.method, route, 200, startTimeNs);
    return;
  }

  if (pathName === '/metrics' && req.method === 'GET') {
    try {
      res.writeHead(200, { 'Content-Type': register.contentType });
      res.end(await register.metrics());
      observeRequest(req.method, route, 200, startTimeNs);
    } catch (err) {
      res.writeHead(500, { 'Content-Type': 'text/plain' });
      res.end('Error generating metrics');
      observeRequest(req.method, route, 500, startTimeNs);
    }
    return;
  }

  const htmlPath = path.join(__dirname, 'index.html');
  fs.readFile(htmlPath, (err, content) => {
    if (err) {
      res.writeHead(500, { 'Content-Type': 'text/plain' });
      res.end('Error loading page');
      observeRequest(req.method, route, 500, startTimeNs);
      return;
    }

    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(content);
    observeRequest(req.method, route, 200, startTimeNs);
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Click counter app running at http://localhost:${PORT}`);
});
