#!/usr/bin/env python3
"""Org live preview — HTTP server with SSE livereload.

Usage:  python3 org-live-server.py --dir DIR

Prints PORT:<number> to stdout when ready, then serves:
  - static files under DIR (index.html for dirs)
  - SSE endpoint /live (pushes "reload" when DIR/.live mtime changes)
"""
import argparse
import http.server
import os
import time


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/live':
            self._sse()
        else:
            self._static()

    def _sse(self):
        live = os.path.join(DIR, '.live')
        self.send_response(200)
        self.send_header('Content-Type', 'text/event-stream')
        self.send_header('Cache-Control', 'no-cache')
        self.send_header('Connection', 'keep-alive')
        self.end_headers()
        t0 = os.path.getmtime(live) if os.path.exists(live) else 0
        try:
            while True:
                time.sleep(0.1)
                if os.path.exists(live):
                    t1 = os.path.getmtime(live)
                    if t1 > t0:
                        self.wfile.write(b'data:reload\n\n')
                        self.wfile.flush()
                        t0 = t1
        except BrokenPipeError:
            pass

    def _static(self):
        p = os.path.join(DIR, self.path.lstrip('/'))
        if os.path.isdir(p):
            p = os.path.join(p, 'index.html')
        if os.path.isfile(p):
            self.send_response(200)
            ext = os.path.splitext(p)[1]
            ct = {'.css': 'text/css', '.html': 'text/html',
                  '.js': 'application/javascript'}.get(ext)
            if ct:
                self.send_header('Content-Type', ct)
            self.end_headers()
            with open(p, 'rb') as f:
                self.wfile.write(f.read())
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, *a):
        pass


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--dir', required=True)
    args = parser.parse_args()

    global DIR
    DIR = args.dir

    open(os.path.join(DIR, '.live'), 'w').close()

    httpd = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    port = httpd.server_address[1]
    print(f'PORT:{port}', flush=True)
    httpd.serve_forever()


if __name__ == '__main__':
    main()
