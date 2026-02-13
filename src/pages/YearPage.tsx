import { ChevronLeft, ChevronRight } from 'lucide-react'
import { Link, Navigate, useParams } from 'react-router-dom'

const WEEKDAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']

type MonthData = {
  label: string
  monthIndex: number
  weeks: Date[][]
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

function buildMonthWeeks(year: number, monthIndex: number): Date[][] {
  const start = startOfWeekMonday(new Date(year, monthIndex, 1))
  const end = endOfWeekMonday(new Date(year, monthIndex + 1, 0))
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

function buildYearData(year: number): MonthData[] {
  return Array.from({ length: 12 }, (_, monthIndex) => {
    const label = new Intl.DateTimeFormat(undefined, { month: 'long' }).format(
      new Date(year, monthIndex, 1),
    )
    return {
      label,
      monthIndex,
      weeks: buildMonthWeeks(year, monthIndex),
    }
  })
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

  const months = buildYearData(parsedYear)
  const previousYear = parsedYear > 1 ? parsedYear - 1 : 1
  const nextYear = parsedYear < 9999 ? parsedYear + 1 : 9999

  return (
    <div className="relative min-h-screen overflow-hidden">
      <div className="pointer-events-none absolute -left-20 top-12 h-64 w-64 rounded-full bg-sky-200/70 blur-3xl" />
      <div className="pointer-events-none absolute right-0 top-1/2 h-72 w-72 rounded-full bg-cyan-100/80 blur-3xl" />

      <main className="mx-auto max-w-[1360px] px-4 pb-12 pt-8 md:px-8">
        <header className="mb-6 flex flex-wrap items-center justify-between gap-4">
          <div>
            <p className="font-display text-sm uppercase tracking-[0.22em] text-slate-500">
              The Planner
            </p>
            <h1 className="font-display text-4xl text-slate-900 md:text-5xl">
              {parsedYear}
            </h1>
          </div>

          <div className="flex items-center gap-2 rounded-full border border-slate-300/80 bg-white/70 p-1 shadow-sm backdrop-blur">
            <Link
              aria-label={`Open ${previousYear}`}
              className="inline-flex h-10 w-10 items-center justify-center rounded-full text-slate-600 transition hover:bg-slate-200/70 hover:text-slate-900"
              to={`/year/${previousYear}`}
            >
              <ChevronLeft className="h-5 w-5" />
            </Link>

            <Link
              className="font-display rounded-full bg-slate-900 px-5 py-2 text-sm text-slate-100 transition hover:bg-slate-700"
              to={`/year/${currentYear}`}
            >
              {parsedYear === currentYear ? 'Current year' : 'Go to current'}
            </Link>

            <Link
              aria-label={`Open ${nextYear}`}
              className="inline-flex h-10 w-10 items-center justify-center rounded-full text-slate-600 transition hover:bg-slate-200/70 hover:text-slate-900"
              to={`/year/${nextYear}`}
            >
              <ChevronRight className="h-5 w-5" />
            </Link>
          </div>
        </header>

        <section className="overflow-x-auto rounded-3xl border border-slate-300/80 bg-white/75 shadow-xl backdrop-blur">
          <div className="min-w-[920px]">
            <div className="grid grid-cols-[140px,1fr] border-b border-slate-300 bg-slate-100/80 md:grid-cols-[190px,1fr]">
              <div className="border-r border-slate-300 px-4 py-3 font-display text-xs uppercase tracking-[0.18em] text-slate-500">
                Month
              </div>
              <div className="grid grid-cols-7">
                {WEEKDAYS.map((weekday, index) => (
                  <div
                    className={`px-2 py-3 text-center font-display text-sm text-slate-700 ${
                      index >= 5 ? 'bg-slate-200/70' : ''
                    }`}
                    key={weekday}
                  >
                    {weekday}
                  </div>
                ))}
              </div>
            </div>

            {months.map((month) => (
              <section
                className="grid grid-cols-[140px,1fr] border-b border-slate-300 last:border-b-0 md:grid-cols-[190px,1fr]"
                key={`${parsedYear}-${month.monthIndex}`}
              >
                <aside className="flex items-start border-r border-slate-300 bg-slate-100/85 px-4 py-4">
                  <h2 className="font-display text-2xl font-bold text-slate-900">
                    {month.label}
                  </h2>
                </aside>

                <div className="divide-y divide-slate-200">
                  {month.weeks.map((week, weekIndex) => (
                    <div className="grid grid-cols-7" key={`${month.label}-${weekIndex}`}>
                      {week.map((date, dayIndex) => {
                        const isCurrentMonth =
                          date.getFullYear() === parsedYear &&
                          date.getMonth() === month.monthIndex
                        const cellKey = formatDateKey(date)
                        const isToday = cellKey === todayKey

                        return (
                          <div
                            className={`min-h-[72px] border-l border-slate-200 px-3 py-2 transition ${
                              dayIndex === 0 ? 'border-l-0' : ''
                            } ${dayIndex >= 5 ? 'bg-slate-100/55' : 'bg-white/65'} ${
                              isCurrentMonth ? 'text-slate-800' : 'invisible'
                            }`}
                            key={cellKey}
                          >
                            <span
                              className={`inline-flex h-8 min-w-8 items-center justify-center rounded-full px-2 text-base ${
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
                  ))}
                </div>
              </section>
            ))}
          </div>
        </section>
      </main>
    </div>
  )
}
