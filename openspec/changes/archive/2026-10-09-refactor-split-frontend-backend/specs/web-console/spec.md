## ADDED Requirements

### Requirement: Backend and frontend are separate deployables
The frontend SHALL be a static build that uses only the public routes of the relay. The
backend SHALL NOT embed it. The backend MAY serve a built directory given by `--web-dir`,
disabled by default.

#### Scenario: Default backend
- **WHEN** the server starts without `--web-dir`
- **THEN** `GET /` returns 404 and no static file route exists

#### Scenario: Served from disk
- **WHEN** the server starts with `--web-dir ./dist` and `GET /` is requested
- **THEN** `dist/index.html` is returned, and API routes still take precedence

### Requirement: Channel browser
The console SHALL list channels grouped by their `group`, show name and logo, and filter
by text matching the display name or slug. Selecting a channel starts playback.

#### Scenario: Filter
- **WHEN** the user types "cctv" in the filter
- **THEN** only channels whose name or slug contains "cctv" (case-insensitive) remain,
  and empty groups are hidden

#### Scenario: Empty result
- **WHEN** the filter matches nothing
- **THEN** the list shows a message saying no channel matches and offers a clear-filter
  action

### Requirement: Live player
The console SHALL play `/live/{ch}.m3u8` and show a clear state for loading, playing,
stalled and failed, with a retry action on failure. Playback SHALL stop and release the
media connection when another channel is chosen or the page closes.

#### Scenario: Switch channel
- **WHEN** the user selects a second channel while the first is playing
- **THEN** the first stream is detached before the second loads, and only one playlist is
  polled

#### Scenario: Notice fallback
- **WHEN** the relay redirects to the notice stream
- **THEN** the player shows a banner that the channel is temporarily unavailable

### Requirement: Relay health panel
The console SHALL show relay health from `/health`, refreshed every 5 seconds while the
tab is visible and paused while hidden, and SHALL show an offline state when the request
fails.

#### Scenario: Backend down
- **WHEN** `/health` fails or times out
- **THEN** the panel shows that the relay is unreachable with the last success time, and
  the channel list keeps its last data

### Requirement: Accessibility and responsiveness
The console SHALL be fully keyboard operable with visible focus, meet WCAG AA contrast in
both light and dark schemes, respect `prefers-reduced-motion`, and lay out without
horizontal scrolling from 360 px width.

#### Scenario: Keyboard only
- **WHEN** a user tabs through the page
- **THEN** every channel, the filter, retry and theme controls are reachable and their
  focus is visible

### Requirement: Declarative rendering
Application code SHALL NOT query or mutate the DOM directly. The single permitted
imperative surface is the hook that attaches the HLS engine to the `<video>` element.

#### Scenario: Lint rule
- **WHEN** the lint step runs
- **THEN** it fails on `document.querySelector`, `getElementById`, `innerHTML` and
  `appendChild` outside the player hook
