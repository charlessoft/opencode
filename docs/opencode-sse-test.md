# OpenCode SSE Test

This page documents how to run the local OpenCode server and connect to [`opencode-sse-test.html`](./opencode-sse-test.html).

## Local quickstart on Windows

Start the OpenCode backend in one terminal:

```powershell
bun run --cwd packages/opencode --conditions=browser src/index.ts serve --port 8080
```

If you want to restrict to localhost only, add `--hostname 127.0.0.1`.

You should see output like:

```text
Warning: OPENCODE_SERVER_PASSWORD is not set; server is unsecured.
opencode server listening on http://127.0.0.1:8080
```

> **Note**: The server only provides the HTTP API layer. LLM providers must be configured separately in `.opencode/opencode.jsonc` under the `provider` field, or via environment variables like `OPENCODE_API_KEY_ANTHROPIC`. Without a provider configured, `prompt_async` will fail because no model is available.

Start a local static file server in a second terminal:

```powershell
cd d:\workspace\foxit\opencode
python -m http.server 5500 -d docs
```

Open the test page in your browser:

```text
http://127.0.0.1:5500/opencode-sse-test.html
```

## Values to use in the page

- `Server URL`: `http://127.0.0.1:8080`
- `Workspace Directory`: `D:/workspace/foxit/opencode`

## Click order

1. `Connect SSE`
2. `Create Session`
3. `Send prompt_async`

## Notes

- Open the HTML from a local static server, not `file://`.
- Leave the password blank for this test page. Its SSE connection uses `EventSource` against `/global/event`, and this page does not attach Basic Auth headers to that request.
- The page creates a session, calls `/session/:id/prompt_async`, and watches `/global/event` for streamed updates.
