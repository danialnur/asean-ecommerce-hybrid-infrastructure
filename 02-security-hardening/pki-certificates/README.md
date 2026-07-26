# PKI — Internal CA, CSR, and Signed TLS Certificate

Real OpenSSL output (not simulated), demonstrating the CCNA/Security+ PKI workflow: stand up an internal root
Certificate Authority, generate a Certificate Signing Request for a server, and sign it with that CA — the same
chain-of-trust process a real enterprise uses for internally-issued TLS certs.

## What each file is

| File | What it is |
|---|---|
| `ca-root-key.pem` | The CA's private key (4096-bit RSA) — this is what actually signs certificates |
| `ca-root-cert.pem` | The CA's self-signed root certificate (`CN=CA-ROOT.danny-sec.internal`, 10-year validity) |
| `ecommerce-server-key.pem` | Private key for the K-pop e-commerce web app's TLS certificate |
| `ecommerce-server.csr` | The Certificate Signing Request generated from that key — the *unsigned* ask |
| `ecommerce-server-cert.pem` | The CA-signed certificate — this is what would actually get installed on the web server (or later, the AWS ALB listener in Phase 4) |
| `ecommerce-server-san.cnf` | OpenSSL config used to generate the CSR with a proper Subject Alternative Name extension — modern browsers reject CN-only certs, SAN is what's actually checked |
| `ca-root-cert.srl` | Serial number file OpenSSL maintains automatically when a CA signs certificates |

## How it was built

```
# 1. CA private key
openssl genrsa -out ca-root-key.pem 4096

# 2. Self-signed root CA certificate
openssl req -x509 -new -nodes -key ca-root-key.pem -sha256 -days 3650 \
  -out ca-root-cert.pem \
  -subj "/C=MY/ST=Kuala Lumpur/L=Kuala Lumpur/O=AREHI-SECOPS/OU=IT Security/CN=CA-ROOT.danny-sec.internal"

# 3. Server private key
openssl genrsa -out ecommerce-server-key.pem 2048

# 4. CSR (with SAN, via the .cnf file)
openssl req -new -key ecommerce-server-key.pem -out ecommerce-server.csr -config ecommerce-server-san.cnf

# 5. Sign the CSR with the CA, carrying the SAN extension through
openssl x509 -req -in ecommerce-server.csr \
  -CA ca-root-cert.pem -CAkey ca-root-key.pem -CAcreateserial \
  -out ecommerce-server-cert.pem -days 825 -sha256 \
  -extfile ecommerce-server-san.cnf -extensions v3_req

# 6. Verify the chain of trust
openssl verify -CAfile ca-root-cert.pem ecommerce-server-cert.pem
# -> ecommerce-server-cert.pem: OK
```

## ⚠️ Important — lab/demo keys only, not for real use

These private keys are committed to a public GitHub repo intentionally, as part of demonstrating the PKI
workflow end-to-end. **They protect nothing real** — there's no live server anywhere using them, and the CA has
no relationship to any actual trusted root. Never do this with a real production key; a private key that
protects anything genuine should never leave the machine it was generated on, let alone get committed to
version control.
