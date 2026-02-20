import type { ApiEvent } from '../lib/eventsApi'

const DAY_MS = 24 * 60 * 60 * 1000

export const WEEKDAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
export const MAX_VISIBLE_BARS = 3
export const MAX_VISIBLE_TIMED = 3

export type MonthStartLabel = {
  full: string
  short: string
}

export type CalendarEvent = {
  id: string
  summary: string
  description: string
  start: Date
  end: Date
  location: string
  color: string
  status?: string
  isAllDay?: boolean
  calendarURL?: string
}

export type WeekBar = {
  event: CalendarEvent
  lane: number
  startIdx: number
  endIdx: number
  continuesFromPreviousWeek: boolean
  continuesToNextWeek: boolean
}

export type WeekRenderData = {
  weekBars: WeekBar[]
  shortEventsByDateKey: Record<string, CalendarEvent[]>
  overflowBarsByDateKey: Record<string, number>
  activeBarsByDateKey: Record<string, number>
}

type Placement = {
  event: CalendarEvent
  startIdx: number
  endIdx: number
  continuesFromPreviousWeek: boolean
  continuesToNextWeek: boolean
}

function addDays(date: Date, days: number): Date {
  const next = new Date(date)
  next.setDate(next.getDate() + days)
  return next
}

function startOfDay(date: Date): Date {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate())
}

function startOfWeekMonday(date: Date): Date {
  const dayIndex = (date.getDay() + 6) % 7
  return addDays(date, -dayIndex)
}

function endOfWeekMonday(date: Date): Date {
  const dayIndex = (date.getDay() + 6) % 7
  return addDays(date, 6 - dayIndex)
}

function daysBetween(start: Date, end: Date): number {
  return Math.floor((startOfDay(end).getTime() - startOfDay(start).getTime()) / DAY_MS)
}

function intersectsRange(startA: Date, endA: Date, startB: Date, endB: Date): boolean {
  return startA.getTime() <= endB.getTime() && endA.getTime() >= startB.getTime()
}

function isShortEvent(event: CalendarEvent): boolean {
  return event.end.getTime() - event.start.getTime() < DAY_MS
}

export function isValidYear(value: number): boolean {
  return Number.isInteger(value) && value >= 1 && value <= 9999
}

export function formatDateKey(date: Date): string {
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${date.getFullYear()}-${month}-${day}`
}

export function formatEventTime(date: Date): string {
  return TIME_FORMATTER.format(date)
}

const TIME_FORMATTER = new Intl.DateTimeFormat(undefined, {
  hour: '2-digit',
  minute: '2-digit',
  hour12: false,
})

const RGBA_CACHE = new Map<string, string>()

export function toRgba(color: string, alpha: number): string {
  const cacheKey = `${color}|${alpha}`
  const cached = RGBA_CACHE.get(cacheKey)
  if (cached) {
    return cached
  }

  const normalized = color.replace('#', '').trim()
  if (!/^[0-9a-fA-F]{3}$|^[0-9a-fA-F]{4}$|^[0-9a-fA-F]{6}$|^[0-9a-fA-F]{8}$/.test(normalized)) {
    const fallback = `rgba(123, 150, 83, ${alpha})`
    RGBA_CACHE.set(cacheKey, fallback)
    return fallback
  }

  let full = normalized
  if (normalized.length === 3 || normalized.length === 4) {
    full = normalized
      .split('')
      .map((char) => `${char}${char}`)
      .join('')
  }
  if (full.length === 6) {
    full = `${full}ff`
  }

  const red = Number.parseInt(full.slice(0, 2), 16)
  const green = Number.parseInt(full.slice(2, 4), 16)
  const blue = Number.parseInt(full.slice(4, 6), 16)
  const embeddedAlpha = Number.parseInt(full.slice(6, 8), 16) / 255
  const effectiveAlpha = Math.max(0, Math.min(1, alpha * embeddedAlpha))
  const rgba = `rgba(${red}, ${green}, ${blue}, ${effectiveAlpha})`
  RGBA_CACHE.set(cacheKey, rgba)
  return rgba
}

export function parseApiEvent(raw: ApiEvent): CalendarEvent | null {
  const start = new Date(raw.start)
  const end = new Date(raw.end)

  if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
    return null
  }

  return {
    ...raw,
    start,
    end,
  }
}

export function sortEventsByTime(events: CalendarEvent[]): CalendarEvent[] {
  return [...events].sort((a, b) => {
    const byStart = a.start.getTime() - b.start.getTime()
    if (byStart !== 0) {
      return byStart
    }

    const byEnd = a.end.getTime() - b.end.getTime()
    if (byEnd !== 0) {
      return byEnd
    }

    return a.summary.localeCompare(b.summary)
  })
}

export function buildYearWeeks(year: number): Date[][] {
  const start = startOfWeekMonday(new Date(year, 0, 1))
  const end = endOfWeekMonday(new Date(year, 11, 31))
  const weeks: Date[][] = []
  let cursor = start

  while (cursor <= end) {
    const week: Date[] = []
    for (let dayOffset = 0; dayOffset < 7; dayOffset += 1) {
      week.push(addDays(cursor, dayOffset))
    }
    weeks.push(week)
    cursor = addDays(cursor, 7)
  }

  return weeks
}

export function buildMonthStartLabels(weeks: Date[][]): Record<string, MonthStartLabel> {
  const monthFormatter = new Intl.DateTimeFormat(undefined, { month: 'long' })
  const monthShortFormatter = new Intl.DateTimeFormat(undefined, { month: 'short' })
  const labels: Record<string, MonthStartLabel> = {}

  for (const week of weeks) {
    for (const date of week) {
      if (date.getDate() !== 1) {
        continue
      }

      const key = formatDateKey(date)
      labels[key] = {
        full: monthFormatter.format(date),
        short: monthShortFormatter.format(date),
      }
    }
  }

  return labels
}

export function buildWeekRenderData(week: Date[], events: CalendarEvent[]): WeekRenderData {
  const weekKeys = week.map((date) => formatDateKey(date))
  const weekStart = startOfDay(week[0])
  const weekEnd = startOfDay(week[6])

  const shortEventsByDateKey: Record<string, CalendarEvent[]> = Object.fromEntries(
    weekKeys.map((key) => [key, []]),
  )
  const placements: Placement[] = []

  for (const event of events) {
    if (isShortEvent(event)) {
      const key = formatDateKey(event.start)
      if (shortEventsByDateKey[key]) {
        shortEventsByDateKey[key].push(event)
      }
      continue
    }

    const eventStartDay = startOfDay(event.start)
    const eventEndDay = startOfDay(event.end)
    if (!intersectsRange(eventStartDay, eventEndDay, weekStart, weekEnd)) {
      continue
    }

    const startIdx = Math.max(0, daysBetween(weekStart, eventStartDay))
    const endIdx = Math.min(6, daysBetween(weekStart, eventEndDay))
    placements.push({
      event,
      startIdx,
      endIdx,
      continuesFromPreviousWeek: eventStartDay < weekStart,
      continuesToNextWeek: eventEndDay > weekEnd,
    })
  }

  placements.sort((a, b) => {
    if (a.startIdx !== b.startIdx) {
      return a.startIdx - b.startIdx
    }

    const aLen = a.endIdx - a.startIdx
    const bLen = b.endIdx - b.startIdx
    if (aLen !== bLen) {
      return bLen - aLen
    }

    return a.event.start.getTime() - b.event.start.getTime()
  })

  const laneEndIndexes: number[] = []
  const allWeekBars: WeekBar[] = []

  for (const placement of placements) {
    let lane = 0
    for (; lane < laneEndIndexes.length; lane += 1) {
      if (placement.startIdx > laneEndIndexes[lane]) {
        break
      }
    }

    if (lane === laneEndIndexes.length) {
      laneEndIndexes.push(-1)
    }
    laneEndIndexes[lane] = placement.endIdx
    allWeekBars.push({
      event: placement.event,
      lane,
      startIdx: placement.startIdx,
      endIdx: placement.endIdx,
      continuesFromPreviousWeek: placement.continuesFromPreviousWeek,
      continuesToNextWeek: placement.continuesToNextWeek,
    })
  }

  const overflowBarsByDateKey: Record<string, number> = Object.fromEntries(
    weekKeys.map((key) => [key, 0]),
  )
  const activeBarsByDateKey: Record<string, number> = Object.fromEntries(
    weekKeys.map((key) => [key, 0]),
  )

  for (let dayIdx = 0; dayIdx < weekKeys.length; dayIdx += 1) {
    const key = weekKeys[dayIdx]
    const activeBars = allWeekBars.filter((bar) => bar.startIdx <= dayIdx && bar.endIdx >= dayIdx)
    activeBarsByDateKey[key] = activeBars.length
    overflowBarsByDateKey[key] = Math.max(0, activeBars.length - MAX_VISIBLE_BARS)

    shortEventsByDateKey[key].sort((a, b) => a.start.getTime() - b.start.getTime())
  }

  const weekBars = allWeekBars
    .filter((bar) => bar.lane < MAX_VISIBLE_BARS)
    .sort(
      (a, b) =>
        a.lane - b.lane ||
        a.startIdx - b.startIdx ||
        a.event.start.getTime() - b.event.start.getTime(),
    )

  return {
    weekBars,
    shortEventsByDateKey,
    overflowBarsByDateKey,
    activeBarsByDateKey,
  }
}
