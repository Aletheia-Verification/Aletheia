# Aletheia mTLS Configuration Guide

Mutual TLS (mTLS) ensures both the server and client authenticate each other using X.509 certificates. This guide covers end-to-end setup for enterprise Aletheia deployments.

---

## 1. Certificate Generation

### 1.1 Create a Certificate Authority (CA)

```bash
# Generate CA private key (4096-bit RSA)
openssl genrsa -out ca.key 4096

# Generate CA certificate (10-year validity)
openssl req -new -x509 -key ca.key -sha256 -days 3650 \
    -out ca.crt \
    -subj "/C=US/ST=New York/O=Aletheia/CN=Aletheia Internal CA"
```

### 1.2 Generate Server Certificate

```bash
# Server private key
openssl genrsa -out server.key 2048

# Certificate Signing Request (CSR)
openssl req -new -key server.key -out server.csr \
    -subj "/C=US/ST=New York/O=Aletheia/CN=aletheia.internal"

# Create SAN extension file (required for modern TLS)
cat > server_ext.cnf <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=@alt_names
[alt_names]
DNS.1 = aletheia.internal
DNS.2 = localhost
IP.1 = 127.0.0.1
EOF

# Sign with CA (1-year validity)
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key \
    -CAcreateserial -out server.crt -days 365 \
    -sha256 -extfile server_ext.cnf
```

### 1.3 Generate Client Certificate

```bash
# Client private key
openssl genrsa -out client.key 2048

# Client CSR (CN = service name or user identity)
openssl req -new -key client.key -out client.csr \
    -subj "/C=US/ST=New York/O=Acme Bank/CN=migration-engineer-1"

# Create client extension file
cat > client_ext.cnf <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage=digitalSignature
extendedKeyUsage=clientAuth
EOF

# Sign with CA
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key \
    -CAcreateserial -out client.crt -days 365 \
    -sha256 -extfile client_ext.cnf
```

### 1.4 Verify Certificates

```bash
# Verify server cert against CA
openssl verify -CAfile ca.crt server.crt

# Verify client cert against CA
openssl verify -CAfile ca.crt client.crt

# View certificate details
openssl x509 -in server.crt -text -noout
```

---

## 2. Uvicorn TLS Configuration

### 2.1 Server-Side TLS (One-Way)

```bash
uvicorn core_logic:app --host 0.0.0.0 --port 443 \
    --ssl-keyfile /certs/server.key \
    --ssl-certfile /certs/server.crt
```

### 2.2 Mutual TLS (Client Certificate Required)

Uvicorn does not natively support client certificate validation. Use one of these approaches:

**Option A: Reverse proxy (recommended)** — See Section 5.

**Option B: Custom SSL context in code**

Add to startup in `core_logic.py` (or a wrapper script):

```python
import ssl
import uvicorn

ssl_context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ssl_context.load_cert_chain("/certs/server.crt", "/certs/server.key")
ssl_context.load_verify_locations("/certs/ca.crt")
ssl_context.verify_mode = ssl.CERT_REQUIRED  # Require client cert

uvicorn.run(
    "core_logic:app",
    host="0.0.0.0",
    port=443,
    ssl=ssl_context,
)
```

### 2.3 Client-Side Configuration

```bash
# curl with client cert
curl --cert client.crt --key client.key --cacert ca.crt \
    https://aletheia.internal:443/api/health

# Python requests
import requests
response = requests.get(
    "https://aletheia.internal:443/api/health",
    cert=("client.crt", "client.key"),
    verify="ca.crt",
)
```

---

## 3. FastAPI Middleware for Client Certificate Validation

If running behind a reverse proxy that forwards the client certificate, extract it from the `X-Client-Cert` header:

```python
from fastapi import Request, HTTPException
from cryptography import x509
from cryptography.hazmat.backends import default_backend
import base64

TRUSTED_CNS = {"migration-engineer-1", "auditor-service", "batch-runner"}

@app.middleware("http")
async def verify_client_cert(request: Request, call_next):
    # Skip for health checks
    if request.url.path in ("/api/health", "/api/v1/heartbeat"):
        return await call_next(request)

    cert_header = request.headers.get("X-Client-Cert")
    if not cert_header:
        raise HTTPException(403, "Client certificate required")

    try:
        cert_pem = base64.b64decode(cert_header)
        cert = x509.load_pem_x509_certificate(cert_pem, default_backend())
        cn = cert.subject.get_attributes_for_oid(x509.oid.NameOID.COMMON_NAME)[0].value
        if cn not in TRUSTED_CNS:
            raise HTTPException(403, f"Untrusted client: {cn}")
        request.state.client_cn = cn
    except Exception as e:
        raise HTTPException(403, f"Invalid client certificate: {e}")

    return await call_next(request)
```

---

## 4. Docker Compose with Certificate Volumes

```yaml
version: "3.8"

services:
  aletheia:
    image: aletheia:latest
    ports:
      - "443:443"
    volumes:
      - ./certs/server.crt:/certs/server.crt:ro
      - ./certs/server.key:/certs/server.key:ro
      - ./certs/ca.crt:/certs/ca.crt:ro
      - ./vault.db:/app/vault.db
      - ./copybooks:/app/copybooks
      - ./license:/app/license:ro
    environment:
      - ALETHEIA_MODE=connected
      - ALETHEIA_TLS_CERT=/certs/server.crt
      - ALETHEIA_TLS_KEY=/certs/server.key
      - ALETHEIA_TLS_CA=/certs/ca.crt
      - ALETHEIA_TLS_VERIFY_CLIENT=true
    command: >
      python -c "
      import ssl, uvicorn;
      ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);
      ctx.load_cert_chain('/certs/server.crt', '/certs/server.key');
      ctx.load_verify_locations('/certs/ca.crt');
      ctx.verify_mode = ssl.CERT_REQUIRED;
      uvicorn.run('core_logic:app', host='0.0.0.0', port=443, ssl=ctx)
      "
```

### Directory Structure

```
project/
  certs/
    ca.crt          # Certificate Authority
    ca.key          # CA private key (keep secure, do NOT mount)
    server.crt      # Server certificate
    server.key      # Server private key
    client.crt      # Client certificate (distribute to engineers)
    client.key      # Client private key (distribute to engineers)
  docker-compose.yml
```

---

## 5. Nginx Reverse Proxy mTLS Configuration

### 5.1 Nginx Configuration

```nginx
upstream aletheia {
    server 127.0.0.1:8000;
}

server {
    listen 443 ssl;
    server_name aletheia.internal;

    # Server certificate
    ssl_certificate     /etc/nginx/certs/server.crt;
    ssl_certificate_key /etc/nginx/certs/server.key;

    # Client certificate verification (mTLS)
    ssl_client_certificate /etc/nginx/certs/ca.crt;
    ssl_verify_client on;
    ssl_verify_depth 2;

    # TLS hardening
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # HSTS
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Forward client certificate to backend
    proxy_set_header X-Client-Cert $ssl_client_escaped_cert;
    proxy_set_header X-Client-CN $ssl_client_s_dn_cn;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Host $host;

    # Proxy to Aletheia backend (plain HTTP internally)
    location / {
        proxy_pass http://aletheia;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;

        # Large file uploads (Shadow Diff)
        client_max_body_size 50g;
        proxy_request_buffering off;
    }
}
```

### 5.2 Docker Compose with Nginx

```yaml
version: "3.8"

services:
  nginx:
    image: nginx:alpine
    ports:
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
      - ./certs:/etc/nginx/certs:ro
    depends_on:
      - aletheia

  aletheia:
    image: aletheia:latest
    expose:
      - "8000"
    volumes:
      - ./vault.db:/app/vault.db
      - ./copybooks:/app/copybooks
    command: uvicorn core_logic:app --host 0.0.0.0 --port 8000
```

---

## 6. Certificate Rotation Procedures

### 6.1 Server Certificate Rotation (Zero-Downtime)

```bash
# 1. Generate new server cert (before current expires)
openssl genrsa -out server_new.key 2048
openssl req -new -key server_new.key -out server_new.csr \
    -subj "/C=US/ST=New York/O=Aletheia/CN=aletheia.internal"
openssl x509 -req -in server_new.csr -CA ca.crt -CAkey ca.key \
    -CAcreateserial -out server_new.crt -days 365 \
    -sha256 -extfile server_ext.cnf

# 2. Replace cert files
cp server_new.crt certs/server.crt
cp server_new.key certs/server.key

# 3. Reload nginx (zero downtime)
docker compose exec nginx nginx -s reload

# 4. Or restart Aletheia if using direct uvicorn TLS
docker compose restart aletheia
```

### 6.2 Client Certificate Rotation

```bash
# 1. Generate new client cert
openssl genrsa -out client_new.key 2048
openssl req -new -key client_new.key -out client_new.csr \
    -subj "/C=US/ST=New York/O=Acme Bank/CN=migration-engineer-1"
openssl x509 -req -in client_new.csr -CA ca.crt -CAkey ca.key \
    -CAcreateserial -out client_new.crt -days 365 \
    -sha256 -extfile client_ext.cnf

# 2. Distribute new cert+key to client
# 3. Old cert remains valid until expiry (grace period)
```

### 6.3 CA Certificate Rotation (Planned Downtime)

CA rotation requires replacing all server and client certs:

```bash
# 1. Generate new CA
openssl genrsa -out ca_new.key 4096
openssl req -new -x509 -key ca_new.key -sha256 -days 3650 \
    -out ca_new.crt \
    -subj "/C=US/ST=New York/O=Aletheia/CN=Aletheia Internal CA v2"

# 2. Cross-sign: create a bundle that trusts both CAs during transition
cat ca.crt ca_new.crt > ca_bundle.crt

# 3. Update nginx to trust bundle
# ssl_client_certificate /etc/nginx/certs/ca_bundle.crt;

# 4. Re-issue all server and client certs with new CA
# 5. After all clients updated, remove old CA from bundle

# 6. Verify no clients still use old CA
openssl crl -in ca_old.crl -text -noout  # if using CRL
```

### 6.4 Monitoring Certificate Expiry

```bash
# Check days until expiry
openssl x509 -in server.crt -noout -enddate

# Script: warn if < 30 days
EXPIRY=$(openssl x509 -in server.crt -noout -enddate | cut -d= -f2)
EXPIRY_EPOCH=$(date -d "$EXPIRY" +%s)
NOW_EPOCH=$(date +%s)
DAYS_LEFT=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))
if [ "$DAYS_LEFT" -lt 30 ]; then
    echo "WARNING: Server cert expires in $DAYS_LEFT days"
fi
```

---

## Quick Reference

| Component | Certificate | Purpose |
|-----------|-------------|---------|
| `ca.crt` | CA certificate | Trust anchor for all certs |
| `ca.key` | CA private key | Signs server/client certs (keep offline) |
| `server.crt` + `server.key` | Server identity | Proves Aletheia server is authentic |
| `client.crt` + `client.key` | Client identity | Proves engineer/service is authorized |

| File Location | Owner | Permissions |
|---------------|-------|-------------|
| `ca.key` | Offline/HSM | `400` (owner read only) |
| `server.key` | Aletheia service | `400` |
| `client.key` | Engineer workstation | `400` |
| `*.crt` | Public | `644` |
