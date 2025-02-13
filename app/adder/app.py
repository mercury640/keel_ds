import os
import sys
import logging
from flask import Flask, request, render_template
import psycopg2
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

# DB conf
DB_CONFIG = {
    'dbname': os.environ.get('DB_NAME'),
    'user': os.environ.get('DB_USER'),
    'password': os.environ.get('DB_PASSWORD',),
    'host': os.environ.get('DB_HOST'),
    'port': os.environ.get('DB_PORT')
}

@app.route('/', methods=['GET', 'POST'])
def adder_page():
    conn = psycopg2.connect(**DB_CONFIG)
    cur = conn.cursor()
    
    if request.method == 'POST':
        value = request.form.get('value')
        if value and value.isdigit():
            ip_address = request.remote_addr
            cur.execute("INSERT INTO keel.info (value, ip) VALUES (%s, %s)", (int(value), ip_address))
            conn.commit()
    
    cur.execute("SELECT COALESCE(SUM(value), 0) FROM keel.info")
    total_sum = cur.fetchone()[0]
    
    cur.close()
    conn.close()
    
    return render_template('index.html', total_sum=total_sum)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=True)
