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

## shadcn/ui

Add components with:

```bash
pnpm dlx shadcn@latest add button
```
