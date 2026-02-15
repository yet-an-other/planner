import { useEffect, useState } from 'react'
import { GoogleCalendarClient } from '../lib/google/googleCalendarClient'
import type { GoogleAuthSession } from '../lib/google/googleAuth.model'
import { parseApiEvent, sortEventsByTime } from './yearPage.model'
import type { CalendarEvent } from './yearPage.model'

type UseYearEventsResult = {
  events: CalendarEvent[]
  loading: boolean
  fetchError: string | null
}

export function useYearEvents(year: number, session: GoogleAuthSession | null): UseYearEventsResult {
  const [events, setEvents] = useState<CalendarEvent[]>([])
  const [loading, setLoading] = useState(false)
  const [fetchError, setFetchError] = useState<string | null>(null)

  useEffect(() => {
    if (!session) {
      setEvents([])
      setLoading(false)
      setFetchError(null)
      return
    }

    let calendarClient: GoogleCalendarClient
    try {
      calendarClient = GoogleCalendarClient.fromEnv(
        {
          VITE_GOOGLE_CALENDAR_ID: import.meta.env.VITE_GOOGLE_CALENDAR_ID,
        },
        session.accessToken,
      )
    } catch (error) {
      setEvents([])
      setLoading(false)
      setFetchError((error as Error).message)
      return
    }

    const controller = new AbortController()

    async function loadEvents() {
      setLoading(true)
      setFetchError(null)

      try {
        const payload = await calendarClient.getEventsForYear(year, controller.signal)
        const parsed = payload
          .map(parseApiEvent)
          .filter((event): event is CalendarEvent => event !== null)

        setEvents(sortEventsByTime(parsed))
      } catch (error) {
        if ((error as Error).name === 'AbortError') {
          return
        }

        setEvents([])
        setFetchError((error as Error).message)
      } finally {
        setLoading(false)
      }
    }

    void loadEvents()

    return () => {
      controller.abort()
    }
  }, [session, year])

  return {
    events,
    loading,
    fetchError,
  }
}
