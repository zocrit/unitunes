# UniTunes

Android app that converts music links between Spotify, YouTube Music, and Tidal.

Share a link from any of the three services and get a converted link for whichever platform you want.

## Requirements

- Flutter SDK (3.7+)
- (Optional) Spotify API credentials from the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)

## Running

The app works out of the box by scraping metadata from music pages. If you want to use the Spotify API as a fallback for parsing and searching, pass credentials:

```bash
flutter run \
  --dart-define=SPOTIFY_CLIENT_ID=your_id \
  --dart-define=SPOTIFY_CLIENT_SECRET=your_secret
```

## How it works

When you share a music link to UniTunes, Android shows three share targets (one per platform). The app figures out which service the link is from, scrapes track/artist/album info from the page, and searches the target service.

Spotify links are parsed from JSON-LD metadata on the page, or via the Spotify API if credentials are configured. YouTube Music and Tidal links use OpenGraph meta tags. On the search side, YouTube Music goes through the InnerTube API, Spotify uses its API when available, and Tidal just builds a search URL since there's no public API worth dealing with.

## Platform support

Android only for now, other platforms support will be coming later.

## License

MIT
