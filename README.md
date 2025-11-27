# UniTunes

Android app that converts Spotify links to YouTube Music or Tidal.

Share a Spotify link to the app, pick which service you want, and get a converted link back.

## Requirements

- Flutter SDK (3.7+)
- (Optional) Spotify API credentials from the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)

## Running

```bash
flutter pub get
flutter run
```

The app works out of the box by scraping metadata from Spotify pages. If you want to use the Spotify API as a fallback, pass credentials:

```bash
flutter run \
  --dart-define=SPOTIFY_CLIENT_ID=your_id \
  --dart-define=SPOTIFY_CLIENT_SECRET=your_secret
```

## How it works

When you share a Spotify link (track, album, or artist) to UniTunes, Android shows two share targets: "YouTube Music" and "Tidal". The app pulls track/artist/album info from the Spotify page, searches the target service, and gives you a direct link.

YouTube Music search goes through the InnerTube API. Tidal just builds a search URL since there's no public API worth dealing with.

## Platform support

Android only for now. The Flutter project has the usual iOS/macOS/Linux/Windows scaffolding but none of the native share intent handling is wired up for those platforms.

## License

MIT
