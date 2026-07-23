from http.server import HTTPServer, SimpleHTTPRequestHandler

class CORSRequestHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header(
            'Access-Control-Allow-Origin',
            '*'
        )
        super().end_headers()

server = HTTPServer(
    ('localhost', 8000),
    CORSRequestHandler
)

print("Server läuft auf http://localhost:8000")

server.serve_forever()