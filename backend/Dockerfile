FROM python:3.12-slim

WORKDIR /app

# System deps (Pillow, psycopg binary, ffmpeg for voice transcoding)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source
COPY . .

# Create persistent directories
RUN mkdir -p /app/data /app/media

# Run database migrations then start the server
CMD ["sh", "-c", "alembic upgrade head || alembic stamp head; gunicorn app.main:app \
  --workers 2 \
  --worker-class uvicorn.workers.UvicornWorker \
  --bind 0.0.0.0:8000 \
  --timeout 120"]

