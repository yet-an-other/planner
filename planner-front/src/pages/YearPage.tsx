import { useCallback, useMemo, useState } from 'react'
import { ChevronLeft, ChevronRight, CircleUserRound, LogOut } from 'lucide-react'
import { Link, Navigate, useLocation, useNavigate, useParams } from 'react-router-dom'
import { GoogleCalendarClient } from '../lib/google/googleCalendarClient'
import { useGoogleAuth } from '../lib/google/useGoogleAuth'
import { EventDetailsDialog } from './EventDetailsDialog'
import { useYearEvents } from './useYearEvents'
import {
  MAX_VISIBLE_TIMED,
  WEEKDAYS,
  buildMonthStartLabels,
  buildWeekRenderData,
  buildYearWeeks,
  formatDateKey,
  formatEventTime,
  isValidYear,
  parseApiEvent,
  toRgba,
} from './yearPage.model'
import type { CalendarEvent } from './yearPage.model'

export function YearPage() {
  const now = new Date()
  const todayKey = formatDateKey(now)
  const currentYear = now.getFullYear()
  const location = useLocation()
  const navigate = useNavigate()
  const { year: yearParam } = useParams()
  const parsedYear = Number(yearParam)
  const hasValidYear = isValidYear(parsedYear)
  const calendarYear = hasValidYear ? parsedYear : currentYear

  const { authError, profile, session, signIn, signOut, status } = useGoogleAuth()
  const { events, loading, fetchError } = useYearEvents(calendarYear, session)
  const [selectedEvent, setSelectedEvent] = useState<CalendarEvent | null>(null)
  const calendarClient = useMemo(() => {
    if (!session) {
      return null
    }

    try {
      return GoogleCalendarClient.fromEnv(
        {
          VITE_GOOGLE_CALENDAR_ID: import.meta.env.VITE_GOOGLE_CALENDAR_ID,
        },
        session.accessToken,
      )
    } catch {
      return null
    }
  }, [session])

  const weeks = useMemo(() => buildYearWeeks(calendarYear), [calendarYear])
  const monthStartLabels = useMemo(() => buildMonthStartLabels(weeks), [weeks])
  const weekRenderData = useMemo(
    () => weeks.map((week) => buildWeekRenderData(week, events)),
    [weeks, events],
  )

  const previousYear = calendarYear > 1 ? calendarYear - 1 : 1
  const nextYear = calendarYear < 9999 ? calendarYear + 1 : 9999
  const userLabel = profile?.name ?? profile?.email ?? 'Google account'
  const openEventDetails = useCallback(
    (event: CalendarEvent) => {
      setSelectedEvent(event)

      if (event.description.trim() || !calendarClient) {
        return
      }

      void calendarClient
        .getEventDetails(event.id)
        .then((rawDetails) => {
          if (!rawDetails) {
            return
          }

          const parsedDetails = parseApiEvent(rawDetails)
          if (!parsedDetails) {
            return
          }

          setSelectedEvent((currentEvent) => {
            if (!currentEvent || currentEvent.id !== event.id) {
              return currentEvent
            }

            return {
              ...currentEvent,
              ...parsedDetails,
            }
          })
        })
        .catch(() => {
          // Keep base event details if extra fetch fails.
        })
    },
    [calendarClient],
  )

  if (!hasValidYear) {
    return <Navigate replace to={`/year/${currentYear}`} />
  }

  return (
    <div className="relative min-h-screen overflow-hidden">
      <div className="pointer-events-none absolute -left-20 top-12 h-64 w-64 rounded-full bg-lime-200/70 blur-3xl" />
      <div className="pointer-events-none absolute right-0 top-1/2 h-72 w-72 rounded-full bg-emerald-100/80 blur-3xl" />

      <main className="flex h-[100dvh] w-full flex-col pt-4 sm:pt-6">
        <header className="mb-3 grid shrink-0 grid-cols-[1fr_auto_1fr] items-start gap-3 px-2 sm:mb-4 sm:gap-4 sm:px-4 md:px-8">
          <div className="justify-self-start">
            <p className="font-display text-[10px] uppercase tracking-[0.18em] text-slate-500 sm:text-sm sm:tracking-[0.22em]">
              The Planner
            </p>
          </div>

          <div className="flex items-center gap-1 sm:gap-1.5">
            <Link
              aria-label={`Open ${previousYear}`}
              className="inline-flex h-5 w-5 items-center justify-center rounded-full border border-slate-300/80 bg-white/70 text-slate-600 shadow-sm backdrop-blur transition hover:bg-slate-200/70 hover:text-slate-900 sm:h-6 sm:w-6"
              to={`/year/${previousYear}`}
            >
              <ChevronLeft className="h-2.5 w-2.5 sm:h-3 sm:w-3" />
            </Link>

            <h1
              className="font-display cursor-pointer select-none text-3xl leading-none text-slate-900 sm:text-4xl md:text-5xl"
              onDoubleClick={() => {
                navigate(`/year/${currentYear}`)
              }}
              title="Double-click to jump to current year"
            >
              {calendarYear}
            </h1>

            <Link
              aria-label={`Open ${nextYear}`}
              className="inline-flex h-5 w-5 items-center justify-center rounded-full border border-slate-300/80 bg-white/70 text-slate-600 shadow-sm backdrop-blur transition hover:bg-slate-200/70 hover:text-slate-900 sm:h-6 sm:w-6"
              to={`/year/${nextYear}`}
            >
              <ChevronRight className="h-2.5 w-2.5 sm:h-3 sm:w-3" />
            </Link>
          </div>

          <div className="flex w-40 flex-col items-stretch gap-1.5 justify-self-end sm:w-44">
            {status === 'authenticated' ? (
              <button
                className="inline-flex h-8 w-full items-center justify-between rounded-full border border-slate-300/80 bg-white/70 px-2.5 text-[11px] text-slate-700 shadow-sm backdrop-blur transition hover:bg-slate-100/80 hover:text-slate-900 sm:h-9 sm:px-3 sm:text-xs"
                onClick={() => {
                  void signOut()
                }}
                title={`Signed in as ${userLabel}. Click to sign out.`}
                type="button"
              >
                <span className="inline-flex min-w-0 items-center gap-2">
                  {profile?.picture ? (
                    <img
                      alt={userLabel}
                      className="h-4 w-4 rounded-full object-cover sm:h-5 sm:w-5"
                      src={profile.picture}
                    />
                  ) : (
                    <CircleUserRound className="h-3.5 w-3.5 sm:h-4 sm:w-4" />
                  )}
                  <span className="truncate">{userLabel}</span>
                </span>
                <LogOut className="h-3.5 w-3.5 shrink-0 sm:h-4 sm:w-4" />
              </button>
            ) : (
              <button
                className="inline-flex h-8 w-full items-center justify-between rounded-full border border-slate-300/80 bg-white/70 px-2.5 text-[11px] text-slate-700 shadow-sm backdrop-blur transition hover:bg-slate-100/80 hover:text-slate-900 disabled:cursor-not-allowed disabled:opacity-60 sm:h-9 sm:px-3 sm:text-xs"
                disabled={status === 'loading'}
                onClick={() => {
                  signIn(`${location.pathname}${location.search}`)
                }}
                type="button"
              >
                <span className="inline-flex min-w-0 items-center gap-2">
                  <CircleUserRound className="h-3.5 w-3.5 sm:h-4 sm:w-4" />
                  <span className="truncate">{status === 'loading' ? 'Checking...' : 'Sign in'}</span>
                </span>
                <span aria-hidden className="h-3.5 w-3.5 shrink-0 sm:h-4 sm:w-4" />
              </button>
            )}

            {authError ? <p className="text-[10px] text-rose-700 sm:text-xs">{authError}</p> : null}
            {status === 'unauthenticated' ? (
              <p className="text-[10px] text-slate-600 sm:text-xs">
                Sign in with Google to load your calendar events.
              </p>
            ) : null}
            {fetchError ? <p className="text-[10px] text-rose-700 sm:text-xs">{fetchError}</p> : null}
            {loading ? <p className="text-[10px] text-slate-600 sm:text-xs">Loading events...</p> : null}
          </div>
        </header>

        <section className="flex min-h-0 w-full flex-1 flex-col overflow-hidden">
          <div className="min-h-0 overflow-y-auto">
            <div className="sticky top-0 z-10 grid grid-cols-7 border-b border-slate-300 bg-slate-100/95 backdrop-blur">
              {WEEKDAYS.map((weekday, index) => (
                <div
                  className={`px-1 py-2 text-center font-display text-[11px] text-slate-700 sm:px-2 sm:py-3 sm:text-sm ${
                    index >= 5 ? 'bg-slate-200/70' : ''
                  }`}
                  key={weekday}
                >
                  {weekday}
                </div>
              ))}
            </div>

            <div className="divide-y divide-slate-200">
              {weeks.map((week, weekIndex) => {
                const monthStartIndex = week.findIndex((date) => {
                  const cellKey = formatDateKey(date)
                  return Boolean(monthStartLabels[cellKey])
                })
                const hasHorizontalMonthDivider = monthStartIndex === 0
                const weekData = weekRenderData[weekIndex]
                const weekBars = weekData.weekBars
                const barsTopClass = monthStartIndex >= 0 ? 'top-6 sm:top-9' : 'top-5 sm:top-9'

                return (
                  <div className="relative" key={`${calendarYear}-week-${weekIndex}`}>
                    <div
                      className={`grid grid-cols-7 ${
                        hasHorizontalMonthDivider
                          ? 'border-t-2 border-t-slate-700 sm:border-t-4'
                          : ''
                      }`}
                    >
                      {week.map((date, dayIndex) => {
                        const cellKey = formatDateKey(date)
                        const isCurrentYear = date.getFullYear() === calendarYear
                        const isToday = cellKey === todayKey
                        const monthLabel = monthStartLabels[cellKey]
                        const isMonthStart = Boolean(monthLabel)
                        const hasVerticalMonthDivider = isMonthStart
                        const leftBorderClass = hasVerticalMonthDivider
                          ? 'border-l-2 border-l-slate-700 sm:border-l-4'
                          : dayIndex === 0
                            ? 'border-l-0'
                            : 'border-l border-slate-200'

                        const barsActiveToday = weekBars.filter(
                          (bar) => bar.startIdx <= dayIndex && bar.endIdx >= dayIndex,
                        )
                        const activeBarsToday = barsActiveToday.length
                        const shortEvents = weekData.shortEventsByDateKey[cellKey] ?? []
                        const overflowBars = weekData.overflowBarsByDateKey[cellKey] ?? 0
                        const timedEventsOffsetClass =
                          activeBarsToday >= 3
                            ? 'mt-14 sm:mt-16'
                            : activeBarsToday === 2
                              ? 'mt-9 sm:mt-11'
                              : activeBarsToday === 1
                                ? 'mt-5 sm:mt-6'
                                : ''

                        return (
                          <div
                            className={`relative min-h-[88px] px-1 py-1 transition sm:min-h-[122px] sm:px-3 sm:py-2 ${leftBorderClass} ${
                              dayIndex >= 5 ? 'bg-slate-100/55' : 'bg-white/65'
                            } ${
                              isCurrentYear ? 'text-slate-800' : 'text-slate-400'
                            }`}
                            key={cellKey}
                          >
                            {isMonthStart ? (
                              <span className="font-display absolute left-1 top-0.5 z-20 text-[8px] font-bold uppercase tracking-[0.06em] text-slate-800 sm:left-2 sm:top-1 sm:text-[11px] sm:tracking-[0.12em]">
                                <span className="sm:hidden">{monthLabel.short}</span>
                                <span className="hidden sm:inline">{monthLabel.full}</span>
                              </span>
                            ) : null}

                            <span
                              className={`absolute right-1 top-0 z-20 inline-flex h-6 min-w-6 items-center justify-center rounded-full px-1 text-xs tabular-nums sm:right-2 sm:top-0.5 sm:h-8 sm:min-w-8 sm:px-2 sm:text-base ${
                                isToday
                                  ? 'font-display border border-slate-900 bg-slate-900 text-white'
                                  : ''
                              }`}
                            >
                              {date.getDate()}
                            </span>

                            <div className={`absolute left-0 right-0 z-10 ${barsTopClass}`}>
                              <div className={`space-y-0.5 ${timedEventsOffsetClass}`}>
                                {overflowBars > 0 ? (
                                  <div className="h-4 text-[8px] leading-4 text-slate-500 sm:h-5 sm:text-[10px] sm:leading-5">
                                    +{overflowBars} more
                                  </div>
                                ) : null}

                                {shortEvents.slice(0, MAX_VISIBLE_TIMED).map((event) => (
                                  <button
                                    className="flex h-4 w-full min-w-0 items-center gap-1 border-0 bg-transparent pl-1 pr-2 text-left text-[8px] leading-4 text-slate-700 transition hover:bg-slate-100/80 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-slate-900 sm:h-5 sm:pl-2 sm:pr-3 sm:text-[11px] sm:leading-5"
                                    key={`${event.id}-${cellKey}-short`}
                                    onClick={() => {
                                      openEventDetails(event)
                                    }}
                                    title={`${formatEventTime(event.start)} ${event.summary}`}
                                    type="button"
                                  >
                                    <span
                                      className="h-1.5 w-1.5 shrink-0 rounded-full"
                                      style={{ backgroundColor: toRgba(event.color, 0.95) }}
                                    />
                                    <span className="min-w-0 flex-1 truncate pr-2 sm:hidden">
                                      {event.summary}
                                    </span>
                                    <span className="hidden shrink-0 tabular-nums sm:inline">
                                      {formatEventTime(event.start)}
                                    </span>
                                    <span className="hidden min-w-0 flex-1 truncate pr-4 sm:block">
                                      {event.summary}
                                    </span>
                                  </button>
                                ))}
                              </div>
                            </div>
                          </div>
                        )
                      })}
                    </div>

                    <div className={`pointer-events-none absolute left-0 right-0 z-30 ${barsTopClass}`}>
                      {weekBars.map((bar) => {
                        const span = bar.endIdx - bar.startIdx + 1
                        const laneTopClass =
                          bar.lane === 0
                            ? 'top-0'
                            : bar.lane === 1
                              ? 'top-[18px] sm:top-[22px]'
                              : 'top-[36px] sm:top-[44px]'
                        const roundedLeftClass = bar.continuesFromPreviousWeek
                          ? ''
                          : 'rounded-l-full'
                        const roundedRightClass = bar.continuesToNextWeek ? '' : 'rounded-r-full'

                        return (
                          <button
                            className={`pointer-events-auto absolute h-4 overflow-hidden border-0 px-1 text-left text-[8px] font-medium leading-4 text-white transition hover:brightness-95 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-slate-900 sm:h-5 sm:px-2 sm:text-[11px] sm:leading-5 ${laneTopClass} ${roundedLeftClass} ${roundedRightClass}`}
                            key={`${bar.event.id}-${bar.lane}-${weekIndex}`}
                            onClick={() => {
                              openEventDetails(bar.event)
                            }}
                            style={{
                              left: `${(bar.startIdx / 7) * 100}%`,
                              width: `${(span / 7) * 100}%`,
                              backgroundColor: toRgba(bar.event.color, 1),
                            }}
                            title={`${bar.event.summary} (${bar.event.start.toISOString()} - ${bar.event.end.toISOString()})`}
                            type="button"
                          >
                            <span className="block truncate">{bar.event.summary}</span>
                          </button>
                        )
                      })}
                    </div>
                  </div>
                )
              })}
            </div>
          </div>
        </section>

        <EventDetailsDialog
          event={selectedEvent}
          onClose={() => {
            setSelectedEvent(null)
          }}
        />
      </main>
    </div>
  )
}
