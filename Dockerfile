# Set Python version to 3.10 for compatibility with puppeteer.py
ARG PYTHON_VERSION=3.10

# Base builder image
FROM python:${PYTHON_VERSION}-slim-bookworm AS builder

# Prevents Rust build issues when installing `cryptography`
ARG CRYPTOGRAPHY_DONT_BUILD_RUST=1

# Install necessary build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    g++ gcc libc-dev libffi-dev \
    libjpeg-dev libssl-dev libxslt-dev \
    make zlib1g-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Create an installation directory
RUN mkdir /install
WORKDIR /install

# Copy requirements
COPY requirements.txt /requirements.txt

# Install Python dependencies
RUN pip install --extra-index-url https://www.piwheels.org/simple --target=/dependencies -r /requirements.txt

# Install Playwright separately to avoid issues on ARM devices
RUN pip install --target=/dependencies playwright~=1.48.0 || \
    echo "WARN: Failed to install Playwright. The application can still run, but Playwright will be disabled."

# Final runtime image
FROM python:${PYTHON_VERSION}-slim-bookworm
LABEL org.opencontainers.image.source="https://github.com/dgtlmoon/changedetection.io"

# Install only required runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libxslt1.1 locales poppler-utils zlib1g \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Ensure logs are not buffered (important for Docker logging)
ENV PYTHONUNBUFFERED=1

# Create datastore directory if not exists
RUN mkdir -p /datastore

# Set OpenSSL security level to allow old cipher suites
RUN sed -i 's/^CipherString = .*/CipherString = DEFAULT@SECLEVEL=1/' /etc/ssl/openssl.cnf

# Copy installed dependencies from builder image
COPY --from=builder /dependencies /usr/local
ENV PYTHONPATH=/usr/local

# Expose port for the app
EXPOSE 5000

# Copy the application source code
COPY changedetectionio /app/changedetectionio
COPY changedetection.py /app/changedetection.py

# Environment variable for logging level
ARG LOGGER_LEVEL=''
ENV LOGGER_LEVEL "$LOGGER_LEVEL"

# Set working directory
WORKDIR /app

# Start the application
CMD ["python", "./changedetection.py", "-d", "/datastore"]
