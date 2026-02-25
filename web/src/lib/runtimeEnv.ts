type PlannerRuntimeEnv = {
  GOOGLE_CLIENT_ID?: string
  GOOGLE_OAUTH_REDIRECT_URI?: string
  GOOGLE_CALENDAR_ID?: string
  VITE_GOOGLE_CLIENT_ID?: string
  VITE_GOOGLE_OAUTH_REDIRECT_URI?: string
  VITE_GOOGLE_CALENDAR_ID?: string
}

function pickFirstNonEmpty(values: Array<string | undefined>): string | undefined {
  for (const value of values) {
    if (typeof value !== 'string') {
      continue
    }

    const trimmed = value.trim()
    if (trimmed) {
      return trimmed
    }
  }

  return undefined
}

function getRuntimeEnv(): PlannerRuntimeEnv {
  if (typeof window === 'undefined') {
    return {}
  }

  return window.__PLANNER_ENV__ ?? {}
}

export function getGoogleOAuthEnv(): {
  VITE_GOOGLE_CLIENT_ID?: string
  VITE_GOOGLE_OAUTH_REDIRECT_URI?: string
} {
  const runtimeEnv = getRuntimeEnv()

  return {
    VITE_GOOGLE_CLIENT_ID: pickFirstNonEmpty([
      runtimeEnv.GOOGLE_CLIENT_ID,
      runtimeEnv.VITE_GOOGLE_CLIENT_ID,
      import.meta.env.VITE_GOOGLE_CLIENT_ID,
    ]),
    VITE_GOOGLE_OAUTH_REDIRECT_URI: pickFirstNonEmpty([
      runtimeEnv.GOOGLE_OAUTH_REDIRECT_URI,
      runtimeEnv.VITE_GOOGLE_OAUTH_REDIRECT_URI,
      import.meta.env.VITE_GOOGLE_OAUTH_REDIRECT_URI,
    ]),
  }
}

export function getGoogleCalendarEnv(): {
  VITE_GOOGLE_CALENDAR_ID?: string
} {
  const runtimeEnv = getRuntimeEnv()

  return {
    VITE_GOOGLE_CALENDAR_ID: pickFirstNonEmpty([
      runtimeEnv.GOOGLE_CALENDAR_ID,
      runtimeEnv.VITE_GOOGLE_CALENDAR_ID,
      import.meta.env.VITE_GOOGLE_CALENDAR_ID,
    ]),
  }
}
