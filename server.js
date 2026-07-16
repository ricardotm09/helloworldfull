const http = require('http');
const fs = require('fs');
const path = require('path');

let clickCount = 0;

const server = http.createServer((req, res) => {
  if (req.url === '/count' && req.method === 'POST') {
    clickCount += 1;
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ count: clickCount }));
    return;
  }

  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok' }));
    return;
  }

  const htmlPath = path.join(__dirname, 'index.html');
  fs.readFile(htmlPath, (err, content) => {
    if (err) {
      res.writeHead(500, { 'Content-Type': 'text/plain' });
      res.end('Error loading page');
      return;
    }

    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(content);
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Click counter app running at http://localhost:${PORT}`);
});
