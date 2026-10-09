# admin-access Specification

## Purpose
Administrator mode: a secret key in the console's address reveals the admin pages, and guessing the key is limited.

## Requirements

### Requirement: Administrator key
The relay SHALL hold one administrator key. It SHALL be taken from the environment variable
`IPTV_ADMIN_KEY` when that is set, and otherwise generated at start-up from the operating
system's random source, with 32 letters and digits. A configured key SHALL have at least 12
characters, all letters, digits, `-` or `_`, or the relay SHALL refuse to start.

#### Scenario: Configured key
- **WHEN** `IPTV_ADMIN_KEY` holds a valid key
- **THEN** that key is the administrator key and it is not printed

#### Scenario: Invalid configured key
- **WHEN** `IPTV_ADMIN_KEY` is shorter than 12 characters or holds a space, slash or dot
- **THEN** start-up fails with a message that names the variable and the rule

#### Scenario: Generated key
- **WHEN** `IPTV_ADMIN_KEY` is not set
- **THEN** a new key is generated, printed once to standard error with the address to open,
  and not written through the log

### Requirement: Key check
`POST /admin/verify` SHALL take the key in a JSON body of at most 1024 bytes and answer 200
for the right key, 403 for any other body, and 429 with `Retry-After` while attempts are
locked. It SHALL compare in time independent of where the keys differ, send
`Cache-Control: no-store`, and never log the key or a guess.

#### Scenario: Right and wrong keys
- **WHEN** the right key is posted, then a wrong key, then a body that is not JSON
- **THEN** the answers are 200, 403 and 403

#### Scenario: Oversized body
- **WHEN** a body larger than 1024 bytes is posted
- **THEN** the answer is 413 and the attempt is not compared

### Requirement: Brute-force limits
Five wrong keys from one client within 15 minutes SHALL lock that client for 15 minutes,
doubling at each further lock up to 24 hours. Sixty wrong keys from all clients within
10 minutes SHALL lock every attempt for 10 minutes. While a lock is active every attempt
SHALL be refused without comparing the key, and a right key SHALL clear the client's count.

#### Scenario: Client lock
- **WHEN** a client posts five wrong keys and then the right one
- **THEN** the right key is refused with 429 and `Retry-After: 900`, and another client is
  not affected

#### Scenario: Lock growth
- **WHEN** a client is locked a second time
- **THEN** the lock lasts 30 minutes

#### Scenario: Overall lock
- **WHEN** sixty wrong keys arrive from different clients inside ten minutes
- **THEN** a new client posting the right key is refused until the overall lock ends

### Requirement: Client address
Failures SHALL be held against the connecting address. When that address is on this machine
or a private network, the address a proxy appended to `X-Forwarded-For` (its last entry),
or else `X-Real-IP`, SHALL be used instead, and these headers SHALL be ignored for any other
peer. The table of clients SHALL stay bounded.

#### Scenario: Spoofed header from outside
- **WHEN** a public address sends `X-Forwarded-For` naming someone else
- **THEN** the failures are counted against the public address

### Requirement: Console page addresses
With `--web-dir`, a path of one word without a dot SHALL answer with the console's
`index.html`, so the key can be carried in the address. Other missing paths SHALL stay 404.
Without `--web-dir` such a path SHALL be 404.

#### Scenario: Address with a key
- **WHEN** `/<key>` is requested and the console directory is set
- **THEN** `index.html` is returned with `Cache-Control: no-cache`
