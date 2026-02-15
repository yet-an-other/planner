export type ApiEvent = {
  id: string
  summary: string
  description: string
  start: string
  end: string
  location: string
  color: string
}

type PlannerApiClientOptions = {
  baseUrl: string
  userID: string
}

type PlannerApiEnv = {
  VITE_PLANNER_API_BASE_URL?: string
  VITE_PLANNER_API_USER_ID?: string
}

export class PlannerApiClient {
  private readonly baseUrl: string
  private readonly userID: string

  constructor(options: PlannerApiClientOptions) {
    this.baseUrl = options.baseUrl
    this.userID = options.userID
  }

  static fromEnv(env: PlannerApiEnv): PlannerApiClient {
    const baseUrl = env.VITE_PLANNER_API_BASE_URL
    if (!baseUrl) {
      throw new Error('Set VITE_PLANNER_API_BASE_URL to load events.')
    }

    return new PlannerApiClient({
      baseUrl,
      userID: env.VITE_PLANNER_API_USER_ID ?? 'demo-user',
    })
  }

  async getEvents(signal?: AbortSignal): Promise<ApiEvent[]> {
    const response = await fetch(this.buildEventsURL(), {
      method: 'GET',
      headers: {
        Accept: 'application/json',
        'user-id': this.userID,
      },
      signal,
    })

    if (!response.ok) {
      throw new Error(`Events request failed (${response.status})`)
    }

    return (await response.json()) as ApiEvent[]
  }

  private buildEventsURL(): string {
    const url = new URL(this.baseUrl)
    const pathname = url.pathname.endsWith('/') ? url.pathname.slice(0, -1) : url.pathname
    const withVersion = pathname.endsWith('/v1') ? pathname : `${pathname}/v1`
    url.pathname = `${withVersion}/events`
    return url.toString()
  }
}
