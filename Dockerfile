# Stage 1 – Builder: install dependencies into an isolated venv
FROM python:3.11-alpine AS builder

WORKDIR /app

# Create a virtual environment so it can be copied cleanly
RUN python -m venv /venv

# Install dependencies (layer-cache friendly: requirements before source)
COPY requirements.txt .
RUN /venv/bin/pip install --no-cache-dir -r requirements.txt

# Upgrade packages with known HIGH CVEs in the venv (CVE-2026-24049, CVE-2026-23949)
RUN /venv/bin/pip install --no-cache-dir --upgrade "wheel>=0.46.2" setuptools

# Stage 2 – Runtime: minimal image, no build tooling
FROM python:3.11-alpine AS runtime

WORKDIR /app

# Copy only the pre-built virtualenv from the builder stage
COPY --from=builder /venv /venv

# Copy application source code
COPY app.py .

# Expose the port 5000
EXPOSE 5000

# Put the venv on PATH so `flask` and `python` resolve correctly
ENV PATH="/venv/bin:$PATH" \
    FLASK_APP=app.py

# Upgrade system Python packages with known HIGH CVEs (CVE-2026-24049, CVE-2026-23949)
RUN /usr/local/bin/pip install --no-cache-dir --upgrade "wheel>=0.46.2" setuptools

# Use a non-root user for security
RUN addgroup -S appuser && adduser -S -G appuser appuser && chown -R appuser /app
USER appuser

# Run the application
CMD ["flask", "run", "--host=0.0.0.0", "--port=5000"]
