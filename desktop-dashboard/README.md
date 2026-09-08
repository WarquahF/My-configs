# Still — minimalist desktop dashboard

A self-contained, responsive desktop-style web interface built with semantic HTML, custom CSS, and vanilla JavaScript. It has no build step and no runtime dependencies.

## Included

- Circular 3D wallpaper coverflow with click, drag, mouse-wheel, pagination, and keyboard controls
- Dual-layer full-screen wallpaper crossfade
- Wallpaper-reactive accent colors
- Glassmorphism tiled layout with a desktop top bar and dock
- Spotify-inspired player with play/pause, previous/next, ±10 second seek, progress, and volume controls
- Searchable command palette and animated mock app windows
- Responsive layouts and `prefers-reduced-motion` support
- Six local SVG wallpapers, so the demo works without image services or API keys

## Run locally

From the repository root:

```sh
python3 -m http.server 8080 --directory desktop-dashboard
```

Then open:

```text
http://localhost:8080
```

You can also open `desktop-dashboard/index.html` directly, although a local server more closely matches normal web deployment.

## Controls

| Action | Control |
|---|---|
| Browse wallpapers | Drag, scroll, click, or use `←` / `→` |
| Apply wallpaper | Select a coverflow card |
| Open launcher | `Ctrl+K` / `Cmd+K` |
| Close launcher/window | `Esc` |
| Play/pause music | `Space` when not typing, or the player button |
| Seek | Progress bar or ±10 second buttons |

## Customize wallpapers

1. Add `.jpg`, `.png`, `.webp`, `.avif`, or `.svg` files under `assets/wallpapers/`.
2. Add an entry to `WALLPAPERS` near the top of `app.js`:

```js
{
  id: "forest",
  name: "Night Forest",
  mood: "deep / natural",
  src: "assets/wallpapers/night-forest.jpg",
  accent: "#55d6a6"
}
```

The `accent` color updates buttons, focus states, active pagination, the player, and ambient glows. The script automatically chooses light or dark text for contrast.

For remote images, put a full `https://...` URL in `src`. Local files are recommended for reliability and privacy.

## Customize the Spotify mock player

Edit `TRACKS` near the top of `app.js`:

```js
{
  title: "Your Track",
  artist: "Your Artist",
  art: "assets/covers/your-cover.jpg",
  duration: 214,
  startAt: 0,
  audio: "assets/audio/your-track.mp3"
}
```

- Leave `audio` empty to use the animated mock timer.
- Add a local audio path to use real HTML audio playback.
- `duration` is in seconds and is only used by mock tracks. Real audio uses its actual metadata duration.
- Browsers require a user click before audio can begin.

## Real Spotify integration

The UI is intentionally API-agnostic. To connect it to Spotify:

1. Create a Spotify developer application and register a localhost callback URL.
2. Use Authorization Code with PKCE in the browser. Never place a Spotify client secret in `app.js`.
3. Fetch current playback from Spotify Web API endpoints such as `/v1/me/player/currently-playing`.
4. Map the response into the existing UI fields or call methods exposed on `window.StillDashboard`.
5. For actual Spotify playback in the browser, use Spotify Web Playback SDK. It generally requires HTTPS outside localhost and an eligible Spotify Premium account.

The useful public hooks are:

```js
StillDashboard.selectWallpaper(index);
StillDashboard.loadTrack(index);
StillDashboard.setPlaying(true);
StillDashboard.openLauncher();
```

For production, keep OAuth refresh-token handling and any client secret on a small backend. Spotify requests reveal account/playback metadata to Spotify and are subject to its rate limits and platform policy.

## Main files

```text
desktop-dashboard/
├── index.html
├── styles.css
├── app.js
├── README.md
└── assets/wallpapers/
    ├── aurora.svg
    ├── ember.svg
    ├── cobalt.svg
    ├── sakura.svg
    ├── jade.svg
    └── mono.svg
```

## Visual tuning

Most global values live at the top of `styles.css`:

- `--panel`: glass panel base color
- `--radius-xl`: tile corner radius
- `--ease-out`: primary motion curve
- `.glass-surface`: blur, transparency, border, and shadow
- `.wallpaper-card`: coverflow card shape and transition timing

The JavaScript changes `--accent`, `--accent-strong`, and `--accent-contrast` whenever a wallpaper is selected.
