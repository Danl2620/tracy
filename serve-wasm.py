#!/usr/bin/env python3
"""
Simple HTTP server with CORS headers for serving WASM profiler.
Enables SharedArrayBuffer support required for pthread/threading.
"""
from http.server import HTTPServer, SimpleHTTPRequestHandler

class CORSRequestHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        # Required headers for SharedArrayBuffer (pthread support)
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        SimpleHTTPRequestHandler.end_headers(self)

if __name__ == '__main__':
    print('Starting server at http://localhost:8000')
    print('Press Ctrl+C to stop')
    HTTPServer(('', 8000), CORSRequestHandler).serve_forever()
