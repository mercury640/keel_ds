import os
import sys
import logging
from logging.handlers import RotatingFileHandler
from flask import Flask, request, render_template
import psycopg2

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

@app.route('/')
def display():
    conn = psycopg2.connect(**DB_CONFIG)
    cur = conn.cursor()
    
    # Fetch the sum of all values
    cur.execute("SELECT COALESCE(SUM(value), 0) FROM keel.info")
    total_sum = cur.fetchone()[0]
    
    # Fetch all records from the database
    cur.execute("SELECT * FROM keel.info")
    records = cur.fetchall()
    
    cur.close()
    conn.close()
    
    return render_template('index.html', total_sum=total_sum, records=records)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5002, debug=True)
