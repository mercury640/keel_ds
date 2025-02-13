import os
from flask import Flask, render_template
import psycopg2

app = Flask(__name__)

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
