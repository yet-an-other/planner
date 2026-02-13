import { ChevronLeft, ChevronRight } from 'lucide-react'
import { Link, Navigate, useParams } from 'react-router-dom'

const WEEKDAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
type MonthStartLabel = {
  full: string
  short: string
}

function formatDateKey(date: Date): string {
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${date.getFullYear()}-${month}-${day}`
}

function addDays(date: Date, days: number): Date {
  const next = new Date(date)
  next.setDate(next.getDate() + days)
  return next
}

function startOfWeekMonday(date: Date): Date {
  const dayIndex = (date.getDay() + 6) % 7
  return addDays(date, -dayIndex)
}

function endOfWeekMonday(date: Date): Date {
  const dayIndex = (date.getDay() + 6) % 7
  return addDays(date, 6 - dayIndex)
}

function buildYearWeeks(year: number): Date[][] {
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

function buildMonthStartLabels(year: number): Record<string, MonthStartLabel> {
  const monthFormatter = new Intl.DateTimeFormat(undefined, { month: 'long' })
  const monthShortFormatter = new Intl.DateTimeFormat(undefined, { month: 'short' })
  return Object.fromEntries(
    Array.from({ length: 12 }, (_, monthIndex) => {
      const monthStart = new Date(year, monthIndex, 1)
      return [
        formatDateKey(monthStart),
        {
          full: monthFormatter.format(monthStart),
          short: monthShortFormatter.format(monthStart),
        },
      ]
    }),
  )
}

function isValidYear(value: number): boolean {
  return Number.isInteger(value) && value >= 1 && value <= 9999
}

export function YearPage() {
  const now = new Date()
  const todayKey = formatDateKey(now)
  const currentYear = now.getFullYear()
  const { year: yearParam } = useParams()
  const parsedYear = Number(yearParam)

  if (!isValidYear(parsedYear)) {
    return <Navigate replace to={`/year/${currentYear}`} />
  }

  const weeks = buildYearWeeks(parsedYear)
  const monthStartLabels = buildMonthStartLabels(parsedYear)
  const previousYear = parsedYear > 1 ? parsedYear - 1 : 1
  const nextYear = parsedYear < 9999 ? parsedYear + 1 : 9999

  return (
    <div className="relative min-h-screen overflow-hidden">
      <div className="pointer-events-none absolute -left-20 top-12 h-64 w-64 rounded-full bg-sky-200/70 blur-3xl" />
      <div className="pointer-events-none absolute right-0 top-1/2 h-72 w-72 rounded-full bg-cyan-100/80 blur-3xl" />

      <main className="mx-auto max-w-[1360px] px-2 pb-10 pt-6 sm:px-4 sm:pb-12 sm:pt-8 md:px-8">
        <header className="mb-4 flex flex-wrap items-center justify-between gap-3 sm:mb-6 sm:gap-4">
          <div>
            <p className="font-display text-[10px] uppercase tracking-[0.18em] text-slate-500 sm:text-sm sm:tracking-[0.22em]">
              The Planner
            </p>
            <h1 className="font-display text-3xl text-slate-900 sm:text-4xl md:text-5xl">
              {parsedYear}
            </h1>
          </div>

          <div className="flex items-center gap-1 rounded-full border border-slate-300/80 bg-white/70 p-0.5 shadow-sm backdrop-blur sm:gap-2 sm:p-1">
            <Link
              aria-label={`Open ${previousYear}`}
              className="inline-flex h-8 w-8 items-center justify-center rounded-full text-slate-600 transition hover:bg-slate-200/70 hover:text-slate-900 sm:h-10 sm:w-10"
              to={`/year/${previousYear}`}
            >
              <ChevronLeft className="h-4 w-4 sm:h-5 sm:w-5" />
            </Link>

            <Link
              className="font-display rounded-full bg-slate-900 px-3 py-1.5 text-xs text-slate-100 transition hover:bg-slate-700 sm:px-5 sm:py-2 sm:text-sm"
              to={`/year/${currentYear}`}
            >
              {parsedYear === currentYear ? 'Current year' : 'Go to current'}
            </Link>

            <Link
              aria-label={`Open ${nextYear}`}
              className="inline-flex h-8 w-8 items-center justify-center rounded-full text-slate-600 transition hover:bg-slate-200/70 hover:text-slate-900 sm:h-10 sm:w-10"
              to={`/year/${nextYear}`}
            >
              <ChevronRight className="h-4 w-4 sm:h-5 sm:w-5" />
            </Link>
          </div>
        </header>

        <section className="overflow-hidden rounded-xl border border-slate-300/80 bg-white/75 shadow-xl backdrop-blur sm:rounded-3xl">
          <div>
            <div className="grid grid-cols-7 border-b border-slate-300 bg-slate-100/80">
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

                return (
                  <div
                    className={`grid grid-cols-7 ${
                      hasHorizontalMonthDivider
                        ? 'border-t-2 border-t-slate-700 sm:border-t-4'
                        : ''
                    }`}
                    key={`${parsedYear}-week-${weekIndex}`}
                  >
                    {week.map((date, dayIndex) => {
                      const cellKey = formatDateKey(date)
                      const isCurrentYear = date.getFullYear() === parsedYear
                      const isToday = cellKey === todayKey
                      const monthLabel = monthStartLabels[cellKey]
                      const isMonthStart = Boolean(monthLabel)
                      const hasVerticalMonthDivider = isMonthStart
                      const leftBorderClass = hasVerticalMonthDivider
                        ? 'border-l-2 border-l-slate-700 sm:border-l-4'
                        : dayIndex === 0
                          ? 'border-l-0'
                          : 'border-l border-slate-200'

                      return (
                        <div
                          className={`relative min-h-[48px] px-1 py-1 transition sm:min-h-[78px] sm:px-3 sm:py-2 ${leftBorderClass} ${
                            dayIndex >= 5 ? 'bg-slate-100/55' : 'bg-white/65'
                          } ${
                            isCurrentYear ? 'text-slate-800' : 'text-slate-400'
                          }`}
                          key={cellKey}
                        >
                          {isMonthStart ? (
                            <span className="font-display absolute left-1 top-0.5 text-[8px] font-bold uppercase tracking-[0.06em] text-slate-800 sm:left-2 sm:top-1 sm:text-[11px] sm:tracking-[0.12em]">
                              <span className="sm:hidden">{monthLabel.short}</span>
                              <span className="hidden sm:inline">{monthLabel.full}</span>
                            </span>
                          ) : null}

                          <span
                            className={`absolute right-1 top-1 inline-flex h-6 min-w-6 items-center justify-center rounded-full px-1 text-xs tabular-nums sm:right-2 sm:top-2 sm:h-8 sm:min-w-8 sm:px-2 sm:text-base ${
                              isToday
                                ? 'font-display border border-slate-900 bg-slate-900 text-white'
                                : ''
                            }`}
                          >
                            {date.getDate()}
                          </span>
                        </div>
                      )
                    })}
                  </div>
                )
              })}
            </div>
          </div>
        </section>
      </main>
    </div>
  )
}
