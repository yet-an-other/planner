import { useEffect, useState } from 'react'
import { PlannerApiClient } from '../lib/plannerApiClient'
import { parseApiEvent, sortEventsByTime } from './yearPage.model'
import type { CalendarEvent } from './yearPage.model'

type UseYearEventsResult = {
  events: CalendarEvent[]
  loading: boolean
  fetchError: string | null
}

export function useYearEvents(): UseYearEventsResult {
  const [events, setEvents] = useState<CalendarEvent[]>([])
  const [loading, setLoading] = useState(false)
  const [fetchError, setFetchError] = useState<string | null>(null)

  useEffect(() => {
    let apiClient: PlannerApiClient
    try {
      apiClient = PlannerApiClient.fromEnv({
        VITE_PLANNER_API_BASE_URL: import.meta.env.VITE_PLANNER_API_BASE_URL,
        VITE_PLANNER_API_USER_ID: import.meta.env.VITE_PLANNER_API_USER_ID,
      })
    } catch (error) {
      setEvents([])
      setFetchError((error as Error).message)
      return
    }

    const controller = new AbortController()

    async function loadEvents() {
      setLoading(true)
      setFetchError(null)

      try {
        const payload = await apiClient.getEvents(controller.signal)
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

    loadEvents()

    return () => {
      controller.abort()
    }
  }, [])

  return {
    events,
    loading,
    fetchError,
  }
}
