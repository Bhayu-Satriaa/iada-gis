FROM python:3.12-slim

WORKDIR /app

# Force rebuild - timestamp: 1789728517
ARG CACHE_BUST=1789728517
RUN echo "Build at $CACHE_BUST"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libgdal-dev \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements_minimal.txt requirements.txt

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy app
COPY . .

# Expose port
EXPOSE 8000

# Start command
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
