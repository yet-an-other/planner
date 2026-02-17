import { useEffect } from 'react'
import { X } from 'lucide-react'
import type { CalendarEvent } from './yearPage.model'

type EventDetailsDialogProps = {
  event: CalendarEvent | null
  onClose: () => void
}

const URL_PATTERN = /https?:\/\/\S+/gi
const AUTO_EVENT_HELPER_TEXT =
  'To see detailed information for automatically created events like this one, use the official Google Calendar app.'
const EMAIL_CREATED_TEXT = 'This event was created from an email you received in Gmail.'

const dateFormatter = new Intl.DateTimeFormat(undefined, {
  weekday: 'short',
  month: 'short',
  day: 'numeric',
  year: 'numeric',
})

const timeFormatter = new Intl.DateTimeFormat(undefined, {
  hour: '2-digit',
  minute: '2-digit',
  hour12: false,
})

function formatDateLabel(date: Date): string {
  return dateFormatter.format(date)
}

function formatTimeLabel(date: Date): string {
  return timeFormatter.format(date)
}

function isSameDay(left: Date, right: Date): boolean {
  return (
    left.getFullYear() === right.getFullYear() &&
    left.getMonth() === right.getMonth() &&
    left.getDate() === right.getDate()
  )
}

function formatEventRange(event: CalendarEvent): string {
  if (event.isAllDay) {
    if (isSameDay(event.start, event.end)) {
      return `${formatDateLabel(event.start)} (all day)`
    }

    return `${formatDateLabel(event.start)} - ${formatDateLabel(event.end)} (all day)`
  }

  if (isSameDay(event.start, event.end)) {
    return `${formatDateLabel(event.start)} · ${formatTimeLabel(event.start)} - ${formatTimeLabel(event.end)}`
  }

  return `${formatDateLabel(event.start)} ${formatTimeLabel(event.start)} - ${formatDateLabel(event.end)} ${formatTimeLabel(event.end)}`
}

export function EventDetailsDialog({ event, onClose }: EventDetailsDialogProps) {
  useEffect(() => {
    if (!event) {
      return
    }

    const previousOverflow = document.body.style.overflow
    document.body.style.overflow = 'hidden'

    const onKeyDown = (keyboardEvent: KeyboardEvent) => {
      if (keyboardEvent.key === 'Escape') {
        onClose()
      }
    }

    window.addEventListener('keydown', onKeyDown)
    return () => {
      document.body.style.overflow = previousOverflow
      window.removeEventListener('keydown', onKeyDown)
    }
  }, [event, onClose])

  if (!event) {
    return null
  }

  const descriptionLinks = Array.from(new Set(event.description.match(URL_PATTERN) ?? []))
  const emailLink = descriptionLinks.find((link) => /mail\.google\.com\/mail/i.test(link)) ?? null
  const filteredLinks = descriptionLinks.filter(
    (link) => !/g\.co\/calendar/i.test(link) && !/mail\.google\.com\/mail/i.test(link),
  )
  const cleanDescription = event.description
    .replace(AUTO_EVENT_HELPER_TEXT, '')
    .replace(URL_PATTERN, '')
    .replace(/\n{3,}/g, '\n\n')
    .trim()
  const descriptionLines = cleanDescription
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line.length > 0)

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/45 p-4"
      onClick={onClose}
    >
      <section
        aria-label="Event details"
        aria-modal="true"
        className="w-full max-w-md rounded-2xl border border-slate-300/70 bg-white p-4 shadow-2xl sm:p-5"
        onClick={(mouseEvent) => {
          mouseEvent.stopPropagation()
        }}
        role="dialog"
      >
        <header className="mb-3 flex items-start justify-between gap-3">
          <div className="min-w-0">
            <div className="mb-1 inline-flex items-center gap-2">
              <span
                className="h-2.5 w-2.5 shrink-0 rounded-full"
                style={{ backgroundColor: event.color }}
              />
              <span className="text-[11px] uppercase tracking-[0.08em] text-slate-500">Event</span>
            </div>
            <h2 className="font-display break-words text-lg leading-tight text-slate-900 sm:text-xl">
              {event.summary}
            </h2>
          </div>

          <button
            aria-label="Close event details"
            className="inline-flex h-8 w-8 items-center justify-center rounded-full text-slate-500 transition hover:bg-slate-200/70 hover:text-slate-800"
            onClick={onClose}
            type="button"
          >
            <X className="h-4 w-4" />
          </button>
        </header>

        <dl className="space-y-2 text-xs text-slate-700 sm:text-sm">
          <div className="flex gap-3">
            <dt className="w-16 shrink-0 text-slate-500">When</dt>
            <dd className="min-w-0">{formatEventRange(event)}</dd>
          </div>

          <div className="flex gap-3">
            <dt className="w-16 shrink-0 text-slate-500">Where</dt>
            <dd className="min-w-0 break-words">{event.location || 'No location'}</dd>
          </div>

          {event.status ? (
            <div className="flex gap-3">
              <dt className="w-16 shrink-0 text-slate-500">Status</dt>
              <dd className="min-w-0 break-words capitalize">{event.status}</dd>
            </div>
          ) : null}
        </dl>

        <div className="mt-4 whitespace-pre-wrap rounded-lg bg-slate-100/80 p-3 text-xs text-slate-700 sm:text-sm">
          {descriptionLines.length > 0 ? (
            <div className="space-y-2">
              {descriptionLines.map((line, index) => (
                <p key={`${line}-${index}`}>
                  {line === EMAIL_CREATED_TEXT && emailLink ? (
                    <>
                      {'This event was created from an email you received in '}
                      <a
                        className="underline decoration-emerald-600 underline-offset-2 transition hover:text-emerald-900"
                        href={emailLink}
                        rel="noreferrer"
                        target="_blank"
                      >
                        Gmail
                      </a>
                      {'.'}
                    </>
                  ) : (
                    line
                  )}
                </p>
              ))}
            </div>
          ) : (
            'No description'
          )}
        </div>

        {filteredLinks.length > 0 ? (
          <div className="mt-3 flex flex-wrap gap-2">
            {filteredLinks.map((link, index) => (
              <a
                className="inline-flex items-center rounded-full border border-emerald-600/40 px-2.5 py-1 text-[11px] text-emerald-800 transition hover:bg-emerald-50 hover:text-emerald-900 sm:text-xs"
                href={link}
                key={`${link}-${index}`}
                rel="noreferrer"
                target="_blank"
              >
                {`Open related link ${index + 1}`}
              </a>
            ))}
          </div>
        ) : null}

        {event.calendarURL ? (
          <div className="mt-4 flex justify-end">
            <a
              className="inline-flex items-center rounded-full border border-emerald-600/40 px-2.5 py-1 text-[11px] text-emerald-800 transition hover:bg-emerald-50 hover:text-emerald-900 sm:text-xs"
              href={event.calendarURL}
              rel="noreferrer"
              target="_blank"
            >
              Calendar
            </a>
          </div>
        ) : null}
      </section>
    </div>
  )
}
