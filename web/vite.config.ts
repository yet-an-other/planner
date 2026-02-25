import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'node:path'
import { execSync } from 'node:child_process'

function normalizeShortSha(value: string): string {
  const trimmed = value.trim()
  if (!trimmed) {
    return ''
  }

  const withoutPrefix = trimmed.startsWith('sha-') ? trimmed.slice(4) : trimmed
  return `sha-${withoutPrefix.slice(0, 7)}`
}

function resolveAppVersion(): string {
  const explicitVersion = process.env.VITE_APP_VERSION
  if (explicitVersion) {
    const normalized = normalizeShortSha(explicitVersion)
    if (normalized) {
      return normalized
    }
  }

  const githubSha = process.env.GITHUB_SHA
  if (githubSha) {
    const normalized = normalizeShortSha(githubSha)
    if (normalized) {
      return normalized
    }
  }

  try {
    const gitSha = execSync('git rev-parse --short HEAD', {
      stdio: ['ignore', 'pipe', 'ignore'],
    })
      .toString()
      .trim()
    const normalized = normalizeShortSha(gitSha)
    if (normalized) {
      return normalized
    }
  } catch {
    // Fallback when git metadata is unavailable in the build context.
  }

  return 'sha-dev'
}

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  define: {
    __APP_VERSION__: JSON.stringify(resolveAppVersion()),
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
})
