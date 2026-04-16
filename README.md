# UniTunes

Android app that converts music links between Spotify, YouTube Music, and Tidal.

Share a link from any of the three services and get a converted link for whichever platform you want.

## Requirements

- Flutter SDK (3.7+)
- API keys for each service you want to search against

## Running

Parsing links works without any keys. Searching needs them:

```bash
flutter run \
  --dart-define=YOUTUBE_MUSIC_API_KEY=your_key \
  --dart-define=TIDAL_TOKEN=your_token \
  --dart-define=SPOTIFY_CLIENT_ID=your_id \
  --dart-define=SPOTIFY_CLIENT_SECRET=your_secret
```

YT Music and Tidal use the public keys baked into their own web apps — grab them from browser dev tools on music.youtube.com and listen.tidal.com. Spotify credentials come from the [developer dashboard](https://developer.spotify.com/dashboard).

Skip a key and that service's search won't work. The rest still does.

## How it works

When you share a music link to UniTunes, Android shows three share targets (one per platform). The app figures out which service the link is from, scrapes track/artist/album info from the page, and searches the target service.

Spotify links are parsed from JSON-LD metadata on the page, or via the Spotify API if credentials are configured. YouTube Music and Tidal links use OpenGraph meta tags. On the search side, YouTube Music goes through the InnerTube API, Spotify uses its API when available, and Tidal just builds a search URL since there's no public API worth dealing with.

## Platform support

Android only for now, other platforms support will be coming later.

## License

MIT
