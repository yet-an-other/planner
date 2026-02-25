export {}

declare global {
  interface Window {
    __PLANNER_ENV__?: {
      GOOGLE_CLIENT_ID?: string
      GOOGLE_OAUTH_REDIRECT_URI?: string
      GOOGLE_CALENDAR_ID?: string
      VITE_GOOGLE_CLIENT_ID?: string
      VITE_GOOGLE_OAUTH_REDIRECT_URI?: string
      VITE_GOOGLE_CALENDAR_ID?: string
    }
  }
}
