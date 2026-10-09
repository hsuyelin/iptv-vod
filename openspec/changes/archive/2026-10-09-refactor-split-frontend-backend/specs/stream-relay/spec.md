## ADDED Requirements

### Requirement: Public routes remain stable
The server SHALL keep serving `GET /list.m3u`, `GET /live/{ch}.m3u8`,
`GET /segment/{ch}/{id}.ts`, `GET /channels` and `GET /health` with unchanged paths,
status codes, content types and JSON field names.

#### Scenario: Existing player loads the playlist
- **WHEN** a client requests `/list.m3u` with a `Host` header
- **THEN** the response is `application/vnd.apple.mpegurl; charset=utf-8` with
  `Cache-Control: no-store`, one notice entry, and one entry per configured channel whose
  URL is absolute and points to `/live/{ch}.m3u8`

#### Scenario: Unknown suffix
- **WHEN** a client requests `/live/cctv1.txt` or `/segment/cctv1/abc.mp4`
- **THEN** the response is 404 with body `{"ok":false,"error":"not found"}`

### Requirement: Fallback notice on channel failure
The server SHALL answer a playlist request for an unknown channel, or for a channel whose
last attempt failed within the notice TTL, with a 307 redirect to the notice stream.

#### Scenario: Unknown channel
- **WHEN** `/live/nope.m3u8` is requested and `nope` is not configured
- **THEN** the response is a 307 redirect to the notice URL

#### Scenario: Channel fails then recovers
- **WHEN** building a channel playlist fails
- **THEN** that channel redirects to the notice URL until the notice TTL elapses, and the
  next request after expiry attempts the upstream again

### Requirement: Channel configuration changes are picked up without restart
The server SHALL serve channel data from memory and SHALL reload the YAML file when its
modification time changes, checking at most once per second. A reload that fails SHALL
keep serving the last valid directory and SHALL be reported by `/health`.

#### Scenario: Edit while running
- **WHEN** `channels.yaml` gains a channel and a request arrives at least one second later
- **THEN** the new channel is listed by `/channels` without a restart

#### Scenario: Broken edit
- **WHEN** `channels.yaml` is replaced with invalid YAML
- **THEN** `/channels` keeps returning the previous channels and `/health` reports the
  reload error

#### Scenario: Startup with no valid file
- **WHEN** the process starts and the file is missing or has no valid channel
- **THEN** startup fails with a non-zero exit and a message naming the file

### Requirement: Bounded per-channel segment work
The server SHALL process segments of one channel strictly in order through a bounded
queue and SHALL NOT hold a lock across an await point. When the queue is full it SHALL
answer 429 with a `Retry-After` header.

#### Scenario: Queue overflow
- **WHEN** more than the queue capacity of segment requests for one channel are pending
- **THEN** the excess requests receive 429 with `Retry-After` and other channels are
  unaffected

#### Scenario: Segment belongs to another channel
- **WHEN** `/segment/{ch}/{id}.ts` names a segment id that was issued for a different
  channel
- **THEN** the response is 502 with `{"ok":false,...}` and the stats count one segment
  error

### Requirement: Health reports counters without blocking requests
`GET /health` SHALL report request, streamed and error counters, the API flow snapshot,
the notice cache and the channel file status, and reading it SHALL NOT delay segment
requests.

#### Scenario: Counters
- **WHEN** one playlist and one successful segment are served
- **THEN** `/health` shows `playlist_requests=1`, `segment_requests=1`,
  `segment_streamed=1`

#### Scenario: Overload is counted separately
- **WHEN** a segment request is answered 429
- **THEN** `segment_rejected` increases by one and `segment_errors` does not
