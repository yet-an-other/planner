export type ApiEvent = {
  id: string
  summary: string
  description: string
  start: string
  end: string
  location: string
  color: string
  status?: string
  isAllDay?: boolean
  calendarURL?: string
}
