FROM python:3.9-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
ENV AWS_DEFAULT_REGION=us-east-1
ENTRYPOINT ["python", "app.py"]
