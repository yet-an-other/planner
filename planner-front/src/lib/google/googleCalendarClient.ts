import type { ApiEvent } from '../eventsApi'

const GOOGLE_CALENDAR_API_ROOT = 'https://www.googleapis.com/calendar/v3'
const DEFAULT_CALENDAR_ID = 'primary'

const GOOGLE_EVENT_COLORS: Record<string, string> = {
  '1': '#7986cbff',
  '2': '#33b679ff',
  '3': '#8e24aaff',
  '4': '#e67c73ff',
  '5': '#f6bf26ff',
  '6': '#f4511eff',
  '7': '#039be5ff',
  '8': '#616161ff',
  '9': '#3f51b5ff',
  '10': '#0b8043ff',
  '11': '#d50000ff',
}

type GoogleCalendarEnv = {
  VITE_GOOGLE_CALENDAR_ID?: string
}

type GoogleCalendarClientOptions = {
  accessToken: string
  calendarID: string
}

type GoogleCalendarEvent = {
  id?: string
  summary?: string
  description?: string
  location?: string
  colorId?: string
  start?: {
    date?: string
    dateTime?: string
  }
  end?: {
    date?: string
    dateTime?: string
  }
}

type GoogleCalendarEventsResponse = {
  items?: GoogleCalendarEvent[]
  nextPageToken?: string
}

function resolveEventColor(rawColorID: string | undefined): string {
  if (!rawColorID) {
    return '#0859dbff'
  }

  return GOOGLE_EVENT_COLORS[rawColorID] ?? '#0859dbff'
}

function parseDateTimeValue(rawValue: string): Date | null {
  const parsed = new Date(rawValue)
  if (Number.isNaN(parsed.getTime())) {
    return null
  }

  return parsed
}

function mapGoogleEvent(event: GoogleCalendarEvent): ApiEvent | null {
  if (!event.id || !event.start || !event.end) {
    return null
  }

  const hasDateTime = Boolean(event.start.dateTime && event.end.dateTime)
  let startDate: Date | null = null
  let endDate: Date | null = null

  if (hasDateTime) {
    startDate = parseDateTimeValue(event.start.dateTime as string)
    endDate = parseDateTimeValue(event.end.dateTime as string)
  } else if (event.start.date && event.end.date) {
    startDate = parseDateTimeValue(`${event.start.date}T00:00:00`)
    const allDayEndExclusive = parseDateTimeValue(`${event.end.date}T00:00:00`)
    if (allDayEndExclusive) {
      endDate = new Date(allDayEndExclusive.getTime() - 1000)
    }
  }

  if (!startDate || !endDate || endDate.getTime() < startDate.getTime()) {
    return null
  }

  return {
    id: event.id,
    summary: event.summary?.trim() || 'Untitled event',
    description: event.description ?? '',
    start: startDate.toISOString(),
    end: endDate.toISOString(),
    location: event.location ?? '',
    color: resolveEventColor(event.colorId),
  }
}

function getRangeStart(year: number): Date {
  const date = new Date(Date.UTC(year, 0, 1, 0, 0, 0, 0))
  date.setUTCDate(date.getUTCDate() - 31)
  return date
}

function getRangeEnd(year: number): Date {
  const date = new Date(Date.UTC(year + 1, 0, 1, 0, 0, 0, 0))
  date.setUTCDate(date.getUTCDate() + 31)
  return date
}

export class GoogleCalendarClient {
  private readonly accessToken: string
  private readonly calendarID: string

  private constructor(options: GoogleCalendarClientOptions) {
    this.accessToken = options.accessToken
    this.calendarID = options.calendarID
  }

  static fromEnv(env: GoogleCalendarEnv, accessToken: string): GoogleCalendarClient {
    if (!accessToken) {
      throw new Error('Google access token is missing. Sign in again.')
    }

    return new GoogleCalendarClient({
      accessToken,
      calendarID: env.VITE_GOOGLE_CALENDAR_ID?.trim() || DEFAULT_CALENDAR_ID,
    })
  }

  async getEventsForYear(year: number, signal?: AbortSignal): Promise<ApiEvent[]> {
    const events: ApiEvent[] = []
    let pageToken: string | undefined

    do {
      const url = this.buildEventsURL(year, pageToken)
      const response = await fetch(url, {
        method: 'GET',
        headers: {
          Accept: 'application/json',
          Authorization: `Bearer ${this.accessToken}`,
        },
        signal,
      })

      if (response.status === 401) {
        throw new Error('Google session expired. Please sign in again.')
      }

      if (!response.ok) {
        throw new Error(`Google Calendar request failed (${response.status})`)
      }

      const payload = (await response.json()) as GoogleCalendarEventsResponse
      for (const item of payload.items ?? []) {
        const mapped = mapGoogleEvent(item)
        if (mapped) {
          events.push(mapped)
        }
      }

      pageToken = payload.nextPageToken
    } while (pageToken)

    return events
  }

  private buildEventsURL(year: number, pageToken: string | undefined): string {
    const url = new URL(
      `${GOOGLE_CALENDAR_API_ROOT}/calendars/${encodeURIComponent(this.calendarID)}/events`,
    )

    url.searchParams.set('singleEvents', 'true')
    url.searchParams.set('orderBy', 'startTime')
    url.searchParams.set('timeMin', getRangeStart(year).toISOString())
    url.searchParams.set('timeMax', getRangeEnd(year).toISOString())
    url.searchParams.set('maxResults', '2500')
    if (pageToken) {
      url.searchParams.set('pageToken', pageToken)
    }

    return url.toString()
  }
}
