FROM python:3.9-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app.py .

# Set environment variables
ENV AWS_DEFAULT_REGION=us-east-1

# Entry point
ENTRYPOINT ["python", "app.py"]