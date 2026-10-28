// LifeFit Node.js REST API Server (Zero-dependency, uses native Node standard library)
const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 3000;
const DATA_FILE = path.join(__dirname, 'data.json');

const MIME_TYPES = {
    '.html': 'text/html; charset=utf-8',
    '.htm': 'text/html; charset=utf-8',
    '.css': 'text/css; charset=utf-8',
    '.js': 'application/javascript; charset=utf-8',
    '.json': 'application/json; charset=utf-8',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.svg': 'image/svg+xml',
    '.ico': 'image/x-icon'
};

const server = http.createServer((req, res) => {
    // CORS headers
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

    if (req.method === 'OPTIONS') {
        res.writeHead(204);
        res.end();
        return;
    }

    const parsedUrl = new URL(req.url, `http://${req.headers.host}`);
    const pathname = parsedUrl.pathname;

    // API Routes
    if (pathname.startsWith('/api/')) {
        res.setHeader('Content-Type', 'application/json; charset=utf-8');

        if (pathname === '/api/status' && req.method === 'GET') {
            res.writeHead(200);
            res.end(JSON.stringify({
                status: 'ok',
                server: 'Node.js Native HTTP',
                version: '2.0',
                timestamp: new Date().toISOString()
            }));
            return;
        }

        if (pathname === '/api/data' && req.method === 'GET') {
            if (fs.existsSync(DATA_FILE)) {
                fs.readFile(DATA_FILE, 'utf8', (err, data) => {
                    if (err) {
                        res.writeHead(500);
                        res.end(JSON.stringify({ error: 'Failed to read data file' }));
                    } else {
                        res.writeHead(200);
                        res.end(data || '{}');
                    }
                });
            } else {
                res.writeHead(200);
                res.end('{}');
            }
            return;
        }

        if (pathname === '/api/data' && req.method === 'POST') {
            let body = '';
            req.on('data', chunk => { body += chunk; });
            req.on('end', () => {
                try {
                    // validate json
                    JSON.parse(body);
                    fs.writeFile(DATA_FILE, body, 'utf8', (err) => {
                        if (err) {
                            res.writeHead(500);
                            res.end(JSON.stringify({ error: 'Failed to save data' }));
                        } else {
                            res.writeHead(200);
                            res.end(JSON.stringify({ success: true, message: 'Data saved' }));
                        }
                    });
                } catch (e) {
                    res.writeHead(400);
                    res.end(JSON.stringify({ error: 'Invalid JSON' }));
                }
            });
            return;
        }

        if (pathname === '/api/reset' && req.method === 'POST') {
            if (fs.existsSync(DATA_FILE)) {
                fs.unlinkSync(DATA_FILE);
            }
            res.writeHead(200);
            res.end(JSON.stringify({ success: true, message: 'Reset completed' }));
            return;
        }

        if (pathname === '/api/export' && req.method === 'GET') {
            res.setHeader('Content-Disposition', 'attachment; filename=lifefit_backup.json');
            if (fs.existsSync(DATA_FILE)) {
                const stream = fs.createReadStream(DATA_FILE);
                stream.pipe(res);
            } else {
                res.writeHead(200);
                res.end('{}');
            }
            return;
        }

        res.writeHead(404);
        res.end(JSON.stringify({ error: 'Endpoint not found' }));
        return;
    }

    // Static file serving
    let safePath = pathname.replace(/^(\.\.[\/\\])+/, '');
    if (safePath === '/' || safePath === '') {
        safePath = '/index.html';
    }

    const filePath = path.join(__dirname, safePath);
    const ext = path.extname(filePath).toLowerCase();
    const contentType = MIME_TYPES[ext] || 'application/octet-stream';

    fs.readFile(filePath, (err, content) => {
        if (err) {
            // Fallback to index.html
            fs.readFile(path.join(__dirname, 'index.html'), (err2, indexContent) => {
                if (err2) {
                    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
                    res.end('404 Not Found');
                } else {
                    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
                    res.end(indexContent);
                }
            });
        } else {
            res.writeHead(200, { 'Content-Type': contentType });
            res.end(content);
        }
    });
});

server.listen(PORT, () => {
    console.log(`LifeFit Node Server running at http://localhost:${PORT}`);
});
