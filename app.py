from flask import Flask, jsonify
import socket
import redis
import os

app = Flask(__name__)

r = redis.Redis(
    host=os.getenv('REDIS_HOST', 'redis'),
    port=6379
)

@app.route("/")
def home():
    visits = r.incr('visits')
    return jsonify({
        "message": "Hello from Docker Compose!",
        "hostname": socket.gethostname(),
        "visits": int(visits)
    })


@app.route("/health")
def health():
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)