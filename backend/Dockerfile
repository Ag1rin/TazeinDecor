FROM python:3.12-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Ensure fonts directory exists and is accessible
RUN mkdir -p fonts && \
    chmod -R 755 fonts

# Create uploads directory
RUN mkdir -p uploads

# Expose port
EXPOSE 80

# Set environment to production by default
ENV ENVIRONMENT=production

# Run the application
CMD ["python", "main.py"]

