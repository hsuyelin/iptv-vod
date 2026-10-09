# web-console Specification

## Purpose
The operator web console: channel browser, live player and relay health, kept separate from the backend and rendered declaratively.

## Requirements

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

### Requirement: Languages
The console SHALL be available in Simplified Chinese (`zh-CN`), Traditional Chinese
(`zh-TW`) and English (`en`), chosen from a keyboard-operable drop-down. An explicit
choice SHALL be kept across visits, and every message key SHALL exist in all three
languages with the same placeholders.

#### Scenario: First visit
- **WHEN** a visitor with no saved choice arrives
- **THEN** a `zh` tag with a Hant script or the TW, HK or MO region gives `zh-TW`, other
  `zh` tags give `zh-CN`, and `en` tags give `en`

#### Scenario: Default language
- **WHEN** the browser reports no language, or none the console supports
- **THEN** Simplified Chinese is used

#### Scenario: Switch language
- **WHEN** the user opens the language drop-down and picks 繁體中文
- **THEN** all console text, the document language and number formats change at once,
  with no reload, and the choice is remembered

### Requirement: Senior mode
The console SHALL offer a senior mode that enlarges type and controls and lists channels
in one large column with plain labels instead of swipeable rows. The choice SHALL be
remembered, and the chip filters SHALL wrap instead of scrolling sideways.

#### Scenario: Toggle
- **WHEN** the user turns senior mode on
- **THEN** the same channels are shown as list lines, the selected one labelled as on air

### Requirement: Calm dark appearance and responsive layout
The console SHALL use a dark theme with a softened red accent, translucent glass-like
surfaces and rounded corners, and SHALL work from 360 px phones to wide desktops without
sideways page scrolling or covered controls.

#### Scenario: Accent
- **WHEN** the design tokens are checked
- **THEN** the accent's saturation is at most 70% and white text on it meets WCAG AA

#### Scenario: Layout check
- **WHEN** the Playwright layout check runs at phone, tablet and desktop sizes in each
  language and in senior mode
- **THEN** it reports no sideways page overflow, no control outside the viewport and no
  control covered by another element

### Requirement: Paged channel list
The console SHALL show the channel list in pages (24 channels per page, 10 in senior
mode), in display order, with previous and next controls and page numbers. A group that
spans pages SHALL repeat its heading. Changing the filter or the group SHALL return to the
first page, and the channel on air SHALL keep playing when the page changes.

#### Scenario: Next page
- **WHEN** 60 channels match and the user presses next
- **THEN** channels 25 to 48 of the display order are shown and the previous control is
  enabled

### Requirement: Floating player
While a channel is playing and the player has scrolled out of view, the console SHALL show
the player as a floating window with controls to return to the player and to close it,
and SHALL return it to its place when the player is visible again. There SHALL be exactly
one video element and one playback engine at all times, so the stream cannot play twice
or overlap its audio. Closing the floating window SHALL stop the stream.

#### Scenario: Scroll away and back
- **WHEN** the player leaves the view and later returns
- **THEN** the same video element floats and then returns, without restarting playback

### Requirement: Dashboard page
The console SHALL have a dashboard page, reachable by a link and by the address
`#/dashboard`, that shows the relay's state, its counters, a chart of recent throughput
and what needs attention.

#### Scenario: Overview
- **WHEN** the dashboard is open and `/health` answers
- **THEN** it shows that the relay is online, its uptime, the time of the last reading,
  the channel file in use, the segment error rate, and the counters for channels,
  playlists served, segment requests, streamed, rejected and failed, upstream calls and
  upstream queue

#### Scenario: Throughput chart
- **WHEN** at least two health readings have been collected
- **THEN** a chart shows the segments streamed between consecutive readings, otherwise a
  note says readings are being collected

#### Scenario: Unavailable channel
- **WHEN** `/health` lists a channel as showing the notice stream
- **THEN** the dashboard names that channel under "Needs attention", and a broken channel
  file is reported there too

#### Scenario: All clear
- **WHEN** no channel is unavailable and the channel file loads
- **THEN** the dashboard says nothing needs attention

### Requirement: Page title
The document title SHALL be "IPTV" in every language and on every page.

#### Scenario: Title after a language change
- **WHEN** the user switches language or moves between the channels and dashboard pages
- **THEN** the document title remains "IPTV"

### Requirement: Picture placeholder
A picture with no address, or one that fails to load, SHALL be replaced by one shared
placeholder icon instead of a broken-image mark.

#### Scenario: Failed logo
- **WHEN** a channel logo cannot be loaded
- **THEN** the channel tile shows the placeholder icon in its place
