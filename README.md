# Planner (Vite + React + TypeScript)

Starter planner app using:
- Vite
- React + TypeScript
- Tailwind CSS
- shadcn/ui
- pnpm

## Requirements

- Node.js 20+
- pnpm (or Corepack enabled)

If pnpm is not installed globally:

```bash
corepack enable
```

## Getting Started

Install dependencies:

```bash
pnpm install
```

Create env file with Google credentials:

```bash
cp .env.example .env
```

Run development server:

```bash
pnpm dev
```

Required env vars:
- `VITE_GOOGLE_CLIENT_ID`: OAuth client ID from Google Cloud.
- `VITE_GOOGLE_OAUTH_REDIRECT_URI`: Redirect URI configured in the OAuth app (for local dev: `http://localhost:5173`).
- `VITE_GOOGLE_CALENDAR_ID`: Calendar to read, default is `primary`.

Build for production:

```bash
pnpm build
```

Preview production build:

```bash
pnpm preview
```

## Docker

Build and run in a multi-stage Alpine image behind Nginx:

```bash
docker build -t planner .
docker run --rm -p 3000:3000 \
  -e GOOGLE_CLIENT_ID=your-google-client-id.apps.googleusercontent.com \
  -e GOOGLE_OAUTH_REDIRECT_URI=http://localhost:3000 \
  -e GOOGLE_CALENDAR_ID=primary \
  planner
```

The container listens on port `3000`.
Runtime env is read from container variables (`GOOGLE_*` or `VITE_GOOGLE_*`) through `/env-config.js`.

## shadcn/ui

Add components with:

```bash
pnpm dlx shadcn@latest add button
```
