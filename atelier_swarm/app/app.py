"""Mini serveur HTTP de demo : renvoie le hostname du conteneur et la version."""
import os
import socket
from http.server import BaseHTTPRequestHandler, HTTPServer

VERSION = "1"
HOSTNAME = socket.gethostname()


class HelloHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.end_headers()
        message = f"Hello depuis {HOSTNAME} - version {VERSION}\n"
        self.wfile.write(message.encode("utf-8"))


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8080"))
    HTTPServer(("0.0.0.0", port), HelloHandler).serve_forever()
