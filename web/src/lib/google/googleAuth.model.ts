export type GoogleOAuthEnv = {
  VITE_GOOGLE_CLIENT_ID?: string
  VITE_GOOGLE_OAUTH_REDIRECT_URI?: string
}

export type GoogleAuthSession = {
  accessToken: string
  tokenType: string
  scope: string
  expiresAt: number
}

export type GoogleUserProfile = {
  id: string
  email: string
  name: string
  picture: string | null
}
