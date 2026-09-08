# n8n-nodes-playwright (kaovilai fork)

This is an n8n community node. It lets you automate browser actions using Playwright in your n8n workflows.

[n8n](https://n8n.io/) is a [fair-code licensed](https://docs.n8n.io/reference/license/) workflow automation platform.

This is a fork of [toema/n8n-playwright](https://github.com/toema/n8n-playwright), published separately as
`@kaovilai/n8n-nodes-playwright` on GitHub Packages. It exists to fix a real production bug in the upstream
package and add a feature upstream doesn't have:

- **Fixes a browser-close leak**: upstream only calls `browser.close()` on the success path in `execute()`. Any
  error after launch (a hung/failed navigation, a missing selector, a bot-detecting site) leaks the entire
  Chromium process tree forever. This fork wraps the launch in `try`/`finally` so the browser always closes.
  Filed upstream at [toema/n8n-playwright#19](https://github.com/toema/n8n-playwright/issues/19); confirmed
  present in both the version this fork branched from and upstream's latest release as of this writing.
- **Adds browser session reuse across nodes** (a "Session ID" field + "Close Session" operation): fill a form,
  click submit (which navigates to another page), then continue filling that next page's form in a later node
  -- something upstream can't do at all, since each node always opens and closes its own browser. Reuse is
  protected by a per-session lock (so two concurrent node executions sharing a Session ID can't race the same
  page) and capped (`PLAYWRIGHT_MAX_SESSIONS`) so a memory-constrained host can't be OOM'd by too many open
  sessions -- see [Operations](#operations) below.

[Installation](#installation)

[Docker image](#docker-image)

[Operations](#operations)

[Compatibility](#compatibility)

[Resources](#resources)

[Version history](#version-history)

## Installation

If you're running self-hosted n8n and just want the node package (not the prebuilt Docker image below), this
package is published to **GitHub Packages**, not the public npm registry -- npm.pkg.github.com requires auth
even to install a public package, so configure a scope mapping + token first:

```bash
echo "@kaovilai:registry=https://npm.pkg.github.com" >> ~/.npmrc
echo "//npm.pkg.github.com/:_authToken=<a token with read:packages>" >> ~/.npmrc

pnpm install @kaovilai/n8n-nodes-playwright
```

Then follow the [community nodes installation guide](https://docs.n8n.io/integrations/community-nodes/installation/)
to register it with your n8n instance.

Note: installing this way, the package downloads and sets up its own Playwright browser binaries at install
time (~1GB disk space) -- same as upstream. The Docker image below avoids that entirely by baking in Alpine's
system Chromium at build time instead; if you're not already committed to a non-Docker n8n setup, that's the
easier path.

If you need to manually re-trigger the browser setup:

```bash
pnpm rebuild @kaovilai/n8n-nodes-playwright
```

## Docker image

A prebuilt, ready-to-run n8n image with this package (and its browser) already baked in, multi-arch
(linux/amd64, linux/arm64), no install step needed:

```bash
docker pull ghcr.io/kaovilai/n8n-playwright:latest
```

See `DOCKER_README.md` and `DEPLOYMENT_NOTES.md` for compose examples, memory sizing, and the session-reuse
env vars (`PLAYWRIGHT_SESSION_IDLE_TIMEOUT_MS`, `PLAYWRIGHT_MAX_SESSIONS`).

## Operations

This node supports the following operations:

-   Navigate: Go to a specified URL
-   Take Screenshot: Capture a screenshot of a webpage
-   Get Text: Extract text from an element using CSS selector
-   Click Element: Click on an element using CSS selector
-   Fill Form: Fill a form field using CSS selector
-   Close Session: Close a browser session opened with a Session ID, freeing its resources

### Session ID (browser reuse across nodes)

Give two or more Playwright nodes the same **Session ID** to reuse one real browser/page across them, instead
of each node opening and closing its own -- e.g. fill a form, click submit (which navigates), then continue
filling the next page's form in a later node. Leave it empty for the original ephemeral behavior (a fresh,
single-use browser that closes automatically after the node). The URL field becomes optional when continuing
an existing session, so a node can operate on whatever page the session already left off on instead of forcing
a fresh navigation.

Two safety nets protect against a session-mode browser becoming a new leak:
- A session left idle for `PLAYWRIGHT_SESSION_IDLE_TIMEOUT_MS` (default 10 minutes) is closed automatically,
  even if the workflow never calls "Close Session".
- `PLAYWRIGHT_MAX_SESSIONS` (default 3) caps concurrent **new** sessions -- reusing an existing one is never
  blocked by this. Exceeding it throws a clear error; pair this with the node's own "Retry On Fail" + "Wait
  Between Tries" setting so a workflow retries once a slot frees up, rather than in a tight loop.

### Browser Options

-   Choose between Chromium, Firefox, or WebKit
-   Configure headless mode
-   Adjust operation speed with slow motion option

### Screenshot Options

-   Full page capture
-   Custom save path
-   Base64 output

## Compatibility

-   Requires n8n version 1.0.0 or later
-   Tested with Playwright version 1.63.0
-   Supports Windows, macOS, and Linux

### System Requirements

-   Node.js 18.10 or later
-   Approximately 1GB disk space for browser binaries (not applicable to the Docker image, which uses Alpine's system Chromium instead)
-   Additional system dependencies may be required for browser automation

## Resources

-   [n8n community nodes documentation](https://docs.n8n.io/integrations/community-nodes/)
-   [Playwright documentation](https://playwright.dev/docs/intro)
-   [Upstream project](https://github.com/toema/n8n-playwright)

## Version history

### 0.3.0

-   Fix: `browser.close()` now always runs (`try`/`finally`), fixing a leak on any error after launch
-   Add: Session ID field + "Close Session" operation for browser reuse across nodes
-   Add: per-session lock so concurrent nodes sharing a Session ID can't race the same page
-   Add: `PLAYWRIGHT_MAX_SESSIONS` cap + `PLAYWRIGHT_SESSION_IDLE_TIMEOUT_MS` idle reaper
-   Published to GitHub Packages as `@kaovilai/n8n-nodes-playwright` (was previously only usable via this
    repo's Docker image, disconnected from the public npm `n8n-nodes-playwright` package)

### 0.1.*/0.2.*

-   Upstream releases (see [toema/n8n-playwright](https://github.com/toema/n8n-playwright)): initial release,
    basic browser automation operations, support for Chromium/Firefox/WebKit, screenshot and form interaction

### Troubleshooting

If browsers are not installed correctly (non-Docker install only -- see [Docker image](#docker-image) above,
which doesn't need this):

1.  Clean the installation:

```bash
rm -rf ~/.cache/ms-playwright
# or for Windows:
rmdir /s /q %USERPROFILE%\AppData\Local\ms-playwright
```

2.  Rebuild the package:

```bash
pnpm rebuild @kaovilai/n8n-nodes-playwright
```

### License

[MIT](./LICENSE.md)
