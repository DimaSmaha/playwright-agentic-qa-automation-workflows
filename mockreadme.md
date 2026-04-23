# Mock Issue Tracker Callback URL Service

This project is a fake issue tracker backend built for integration and QA testing. It gives you predictable API endpoints that behave like an external system for tasks, bugs, and test cases, so you can test callback and webhook flows without relying on a real tracker.

## What this project is for

Use this service when you need a lightweight mock of an issue-tracking platform:

- Testing callback URL integrations
- Simulating third-party API behavior during local development
- QA or demo environments where a real issue tracker is unnecessary
- Reproducing retry and error behavior with controlled random failures

## Key behavior

- Exposes REST endpoints for tasks, bugs, and test cases
- Returns hardcoded records for `GET /:id` endpoints
- Validates `POST /create` requests with endpoint-specific required fields
- Logs valid create payloads to the server output
- Returns a mocked created entity payload for `POST /create` endpoints
- Applies simulated network conditions to all requests:
  - Artificial delay (`300ms` by default)
  - Random failure rate (`20%` by default, returns HTTP `500`)

## Tech stack

- Node.js
- TypeScript
- Express 5
- ts-node (dev runtime)
- ngrok (optional public tunnel for callback testing)

## Project architecture

The project is organized in a clean layered style:

- `src/domain/models` - TypeScript interfaces (`Task`, `Bug`, `TestCase`)
- `src/application/services` - In-memory mock data and create helpers
- `src/infrastructure/http/controllers` - HTTP handlers
- `src/infrastructure/http/routes` - Route definitions
- `src/shared/middleware` - Request logging, create validation, and delay/failure simulation
- `src/shared/config.ts` - Simulation settings
- `src/app.ts` - App composition and middleware wiring
- `src/server.ts` - Server startup

## API overview

Base URL: `http://localhost:3000`

### Health/root

- `GET /`
  - Response: `"Callback mock server running"`

### Tasks

- `GET /tasks/:id`
  - Example: `GET /tasks/112`
  - Returns a mocked task when found
  - Returns `404` when not found
- `POST /tasks/create`
  - Requires `application/json`
  - Requires `title`, `description`, and `type` as non-empty strings
  - Logs payload to server output
  - Returns `200` with `{ "status": "ok", "data": { ... } }`

### Bugs

- `GET /bugs/:id`
  - Example: `GET /bugs/114`
  - Returns a mocked bug when found
  - Returns `404` when not found
- `POST /bugs/create`
  - Requires `application/json`
  - Requires `title`, `description`, and `type` as non-empty strings
  - Logs payload to server output
  - Returns `200` with `{ "status": "ok", "data": { ... } }`

### Test cases

- `GET /testcases/:id`
  - Example: `GET /testcases/115`
  - Returns a mocked test case when found
  - Returns `404` when not found
- `POST /testcases/create`
  - Requires `application/json`
  - Requires `title` and `type` as non-empty strings
  - Requires `steps` as a non-empty array of non-empty strings
  - Logs payload to server output
  - Returns `200` with `{ "status": "ok", "data": { ... } }`

## Running locally

### 1. Install dependencies

```bash
npm install
```

### 2. Start in development mode

```bash
npm run dev
```

The server runs on `http://localhost:3000`.

### 3. Build and run production-style

```bash
npm run build
npm run start
```

## Available scripts

- `npm run dev` - Run TypeScript directly with `ts-node`
- `npm run build` - Compile TypeScript to `dist/`
- `npm run start` - Run the compiled server from `dist/server.js`
- `npm run ngrok` - Expose local port `3000` via ngrok

## Example requests

### Get an existing task

```bash
curl http://localhost:3000/tasks/112
```

### Create a task

```bash
curl -X POST http://localhost:3000/tasks/create \
  -H "Content-Type: application/json" \
  -d "{\"title\":\"Imported task\",\"description\":\"Create a task received from an external callback\",\"type\":\"story\"}"
```

### Create a bug

```bash
curl -X POST http://localhost:3000/bugs/create \
  -H "Content-Type: application/json" \
  -d "{\"title\":\"Login issue\",\"description\":\"Login button stays disabled after valid input\",\"type\":\"bug\"}"
```

### Create a test case

```bash
curl -X POST http://localhost:3000/testcases/create \
  -H "Content-Type: application/json" \
  -d "{\"title\":\"Verify login flow\",\"type\":\"testcase\",\"steps\":[\"Open the sign-in page\",\"Enter valid credentials\",\"Click Login\",\"Verify the dashboard is displayed\"]}"
```

## Windows curl examples

### `cmd.exe`

Use escaped double quotes for JSON:

```cmd
curl --location http://localhost:3000/bugs/create --header "Content-Type: application/json" --data-raw "{\"title\":\"Login issue\",\"description\":\"Login button stays disabled after valid input\",\"type\":\"bug\"}"
```

### PowerShell

Use `curl.exe` and wrap the JSON body in single quotes:

```powershell
curl.exe --location http://localhost:3000/bugs/create `
  --header "Content-Type: application/json" `
  --data-raw '{"title":"Login issue","description":"Login button stays disabled after valid input","type":"bug"}'
```

## Example responses

### Successful create response

```json
{
  "status": "ok",
  "data": {
    "id": 500,
    "title": "Login issue",
    "description": "Login button stays disabled after valid input",
    "type": "bug",
    "severity": "medium",
    "status": "created",
    "message": "Bug was created successfully in the mocked tracking system."
  }
}
```

### Validation error response

If any of `title`, `description`, or `type` is missing or empty:

```json
{
  "status": "error",
  "message": "Fields title, description, and type are required as non-empty strings in the JSON body.",
  "missingFields": ["title", "description", "type"]
}
```

For `POST /testcases/create`, `steps` must be sent instead of `description`:

```json
{
  "status": "error",
  "message": "Fields title and type are required as non-empty strings, and steps is required as a non-empty string array in the JSON body.",
  "missingFields": ["steps"]
}
```

If the request body is not sent as JSON:

```json
{
  "status": "error",
  "message": "Request body must be sent as application/json."
}
```

## Simulating real-world instability

The service intentionally behaves like an unreliable external dependency. You can adjust this in `src/shared/config.ts`:

- `delayMs` - Adds latency to every request
- `failureRate` - Probability from `0` to `1` of returning random HTTP `500`

Current defaults:

- `delayMs: 300`
- `failureRate: 0.2`

When a simulated failure happens, the response is:

```json
{
  "status": "error",
  "message": "Random simulated failure"
}
```

## Using as a public callback URL with ngrok

If your external system requires a public URL:

1. Start this server with `npm run dev`
2. In another terminal, run `npm run ngrok`
3. Use the generated HTTPS URL plus one of the API routes, for example:

- `https://<your-ngrok-domain>/tasks/create`
- `https://<your-ngrok-domain>/bugs/create`
- `https://<your-ngrok-domain>/testcases/create`
- `https://<your-ngrok-domain>/bugs/114`

## Limitations

- No database persistence; all data is in memory
- No authentication or authorization
- Minimal validation beyond required create fields
- No update or delete endpoints
- Data resets on restart

This is intentional for a lightweight mock service.

## Suggested next improvements

If you want this fake tracker to be more realistic, consider adding:

- Persistent storage such as SQLite or Postgres
- Webhook signature verification
- Retry and dead-letter simulation routes
- Configurable behavior via environment variables
- Automated integration tests
