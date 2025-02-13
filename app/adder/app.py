import os
from flask import Flask, request, render_template
import psycopg2

app = Flask(__name__)

# Database connection configuration
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
