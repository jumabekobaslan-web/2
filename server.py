#!/usr/bin/env python3
"""
LifeFit Python REST API Server
Zero external dependencies required - runs with standard Python 3
"""
import os
import json
from http.server import HTTPServer, SimpleHTTPRequestHandler
import mimetypes

PORT = int(os.environ.get('PORT', 3000))
ROOT = os.path.dirname(os.path.abspath(__file__))
DATA_FILE = os.path.join(ROOT, 'data.json')

class LifeFitHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def _set_cors(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS, DELETE, PUT')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization')

    def do_OPTIONS(self):
        self.send_response(204)
        self._set_cors()
        self.end_headers()

    def do_GET(self):
        if self.path.startswith('/api/'):
            self._handle_api_get()
            return
        # Default file serving
        if self.path == '/':
            self.path = '/index.html'
        return super().do_GET()

    def do_POST(self):
        if self.path.startswith('/api/'):
            self._handle_api_post()
            return
        self.send_error(404, "Endpoint not found")

    def _handle_api_get(self):
        if self.path == '/api/status':
            self.send_response(200)
            self._set_cors()
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.end_headers()
            res = {"status": "ok", "server": "Python 3 Standard Library", "version": "2.0"}
            self.wfile.write(json.dumps(res).encode('utf-8'))
            return

        if self.path == '/api/data':
            self.send_response(200)
            self._set_cors()
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.end_headers()
            if os.path.exists(DATA_FILE):
                with open(DATA_FILE, 'rb') as f:
                    self.wfile.write(f.read())
            else:
                self.wfile.write(b'{}')
            return

        if self.path == '/api/export':
            self.send_response(200)
            self._set_cors()
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Content-Disposition', 'attachment; filename=lifefit_backup.json')
            self.end_headers()
            if os.path.exists(DATA_FILE):
                with open(DATA_FILE, 'rb') as f:
                    self.wfile.write(f.read())
            else:
                self.wfile.write(b'{}')
            return

        self.send_error(404, "API endpoint not found")

    def _handle_api_post(self):
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length).decode('utf-8') if content_length > 0 else ''

        if self.path == '/api/data':
            try:
                # parse json
                parsed = json.loads(body)
                with open(DATA_FILE, 'w', encoding='utf-8') as f:
                    json.dump(parsed, f, ensure_ascii=False, indent=2)
                self.send_response(200)
                self._set_cors()
                self.send_header('Content-Type', 'application/json; charset=utf-8')
                self.end_headers()
                self.wfile.write(b'{"success":true,"message":"Data saved"}')
            except Exception as e:
                self.send_response(400)
                self._set_cors()
                self.send_header('Content-Type', 'application/json; charset=utf-8')
                self.end_headers()
                self.wfile.write(json.dumps({"error": str(e)}).encode('utf-8'))
            return

        if self.path == '/api/reset':
            if os.path.exists(DATA_FILE):
                os.remove(DATA_FILE)
            self.send_response(200)
            self._set_cors()
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.end_headers()
            self.wfile.write(b'{"success":true,"message":"Database reset"}')
            return

        self.send_error(404, "API endpoint not found")

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', PORT), LifeFitHandler)
    print(f"LifeFit Python Server running at http://localhost:{PORT}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping server...")
        server.server_close()
