# Trace media-search relay

This small Node 20+ service keeps the Brave Search credential out of Trace
clients. It searches Brave's open-web image index and exposes only short-lived,
signed media URLs. The fetch route rechecks redirects and public IP addresses to
reduce SSRF risk, validates MIME types, and limits media to 25 MB.

Configure:

```sh
export BRAVE_SEARCH_API_KEY='...'
export MEDIA_PROXY_SECRET='a-long-random-secret'
export PUBLIC_BASE_URL='https://media-search.example.org'
export ALLOWED_ORIGINS='https://trace.example.org'
export PORT=8787
node tool/media_search_relay/server.mjs
```

For Android and Linux, build Trace with the deployed URL. GIPHY is optional and
uses its provider-required direct client integration; its app key is an
identifier embedded in the build, not a backend secret.

```sh
flutter build apk \
  --dart-define=TRACE_MEDIA_SEARCH_ENDPOINT=https://media-search.example.org \
  --dart-define=TRACE_GIPHY_API_KEY=your-giphy-app-key
```

The relay should sit behind production TLS, request-size/time limits, and
durable rate limiting. `ALLOWED_ORIGINS` is needed only for Trace web origins;
native Android/Linux clients do not send browser CORS origins.
