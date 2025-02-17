FROM python:3.12-slim

RUN useradd -ms /bin/bash ds

WORKDIR /app

COPY . /app

RUN pip install --no-cache-dir -r requirements.txt && \
    chown -R ds:ds /app

EXPOSE 5001

CMD ["python", "app.py"]
