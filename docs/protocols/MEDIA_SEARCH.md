# Media search

Trace combines two deliberately different search paths:

- Brave supplies broad open-web GIF and transparent-sticker results through
  `tool/media_search_relay`. Its secret credential never enters a Trace build.
- GIPHY supplies curated GIFs and stickers through its required direct-client
  API. `TRACE_GIPHY_API_KEY` is therefore an app integration identifier visible
  in the compiled client; it must not be treated as a backend secret.

Users do not create provider accounts or enter keys. The Trace distributor owns
the keys and shared quotas. Self-hosters may supply their own build settings.

## Client configuration

Build or run with one or both providers:

```sh
flutter run -d linux \
  --dart-define=TRACE_MEDIA_SEARCH_ENDPOINT=https://media-search.example.org \
  --dart-define=TRACE_GIPHY_API_KEY=your-giphy-app-key
```

`TRACE_MEDIA_SEARCH_ENDPOINT` must be an HTTPS deployment of the relay. See its
README for server environment variables. At least one provider is required for
the search sheet to become active.

## Relay contract

The client calls:

```text
GET /v1/media/search?q=<query>&kind=gif|sticker&safety=open|strict
```

The response is JSON:

```json
{
  "results": [
    {
      "id": "stable-result-id",
      "title": "Result title",
      "previewUrl": "https://relay.example/v1/media/fetch?...",
      "downloadUrl": "https://relay.example/v1/media/fetch?...",
      "mimeType": "image/gif",
      "source": "Brave",
      "width": 480,
      "height": 270
    }
  ]
}
```

Trace currently requests each provider's broadest result set: Brave receives
`safesearch=off` and GIPHY's rating restriction is omitted. This is not a
promise of literally unmoderated content: providers still remove illegal
material and enforce their platform policies.

## Sending and validation

Trace downloads the selected result, accepts only GIF, PNG, WebP, or MP4 media,
limits it to 25 MB, and uploads the bytes to Matrix. Messages do not hotlink the
original result, so they remain available according to the room's Matrix media
retention. The current sticker search sends selected content as interoperable
Matrix image media; native `m.sticker` events and sticker packs remain future
work.

Search terms and client IP addresses are visible to the contacted provider or
relay. Production relays should avoid query logging, use durable rate limits,
and publish a retention policy.

## Android keyboard media

The composer also accepts GIF, PNG, JPEG, and WebP content inserted through
Android's standard rich-content keyboard protocol. This works with any keyboard
that implements Android content insertion and does not require a Trace provider
key. It provides a supported route for content from the separate GIF Keyboard
by Tenor even though Google discontinued the public Tenor developer API in
June 2026. The selected bytes are uploaded to Matrix like other attachments.
