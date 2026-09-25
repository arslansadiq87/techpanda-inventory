# Security Policy

## Reporting a vulnerability

Please do not open a public issue for a security vulnerability. Contact the
repository maintainers privately with a description, reproduction steps, and
the affected version. Allow reasonable time for investigation and a fix before
public disclosure.

## Deployment requirements

- Never commit `.env`, API keys, passwords, private keys, database exports, or
  tunnel tokens.
- Set `JWT_SECRET`, `ADMIN_PASSWORD`, and production database credentials in a
  secret manager or a server-only `.env` file.
- Use HTTPS for remote clients and restrict CORS to trusted origins.
- Rotate any credential that has been exposed in shell history, logs, or a
  previous private deployment.
