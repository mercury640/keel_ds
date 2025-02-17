import os
import sys
import logging
import psycopg2
from flask import Flask, render_template, request, redirect, url_for
from logging.handlers import RotatingFileHandler

app = Flask(__name__)

# Setup rotating file handler
log_handler = RotatingFileHandler('app.log', maxBytes=2 * 1024 * 1024, backupCount=2) 
log_handler.setLevel(logging.INFO)
log_formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
log_handler.setFormatter(log_formatter)

# Add the log handler to Flask’s logger
app.logger.addHandler(log_handler)
app.logger.setLevel(logging.INFO)  # Set the logging level
console_handler = logging.StreamHandler(sys.stdout)
console_handler.setFormatter(log_formatter)
app.logger.addHandler(console_handler)

# Log request
@app.before_request
def log_request_info():
    app.logger.info(f"Request: {request.method} {request.url} from {request.remote_addr}")

# Get database credentials from environment variables
DB_CONFIG = {
    'dbname': os.environ.get('DB_NAME'),
    'user': os.environ.get('DB_USER'),
    'password': os.environ.get('DB_PASSWORD',),
    'host': os.environ.get('DB_HOST'),
    'port': os.environ.get('DB_PORT')
}

@app.route('/', methods=['GET', 'POST'])
def index():
    if request.method == 'POST':
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()
        cur.execute("DELETE FROM keel.info")
        conn.commit()
        cur.close()
        conn.close()
        return redirect(url_for('index'))
    
    return render_template('index.html')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5003, debug=True)