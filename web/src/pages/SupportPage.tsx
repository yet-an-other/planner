import { Mail, MessageSquareWarning, ShieldCheck } from 'lucide-react'
import { Link } from 'react-router-dom'

export function SupportPage() {
  return (
    <main className="min-h-screen px-4 py-8 sm:px-6 sm:py-10">
      <div className="mx-auto flex max-w-4xl flex-col gap-6">
        <header className="rounded-[28px] border border-[#bcc8a8]/70 bg-[#f5f7ef]/95 p-6 shadow-[0_18px_50px_rgba(88,98,56,0.12)] sm:p-8">
          <p className="font-display text-xs uppercase tracking-[0.22em] text-[#5c6c52]">Yet Another Planner</p>
          <h1 className="mt-3 font-display text-3xl text-[#1f2618] sm:text-4xl">Support</h1>
          <p className="mt-4 max-w-2xl text-sm leading-6 text-[#46523f] sm:text-base">
            Contact the developer directly if you need help with Google Calendar connection, event loading,
            App Store access, or anything else related to Planner.
          </p>
        </header>

        <section className="grid gap-4 sm:grid-cols-[1.2fr_0.8fr]">
          <article className="rounded-[24px] border border-[#c8d2bb] bg-white/90 p-6 shadow-sm">
            <div className="flex items-center gap-3">
              <Mail className="h-5 w-5 text-[#506146]" />
              <h2 className="font-display text-xl text-[#20271b]">Contact</h2>
            </div>
            <p className="mt-4 text-sm leading-6 text-[#485343]">
              For support questions, send an email to{' '}
              <a className="font-medium text-[#385f3a] underline underline-offset-4" href="mailto:main@ivan-b.com">
                main@ivan-b.com
              </a>
              .
            </p>
            <p className="mt-3 text-sm leading-6 text-[#485343]">
              Include your device model, iOS or iPadOS version, and a short description of the issue. If the problem
              is related to Google Calendar connection, mention whether it happens during first setup or after the app
              was already connected once.
            </p>
          </article>

          <article className="rounded-[24px] border border-[#c8d2bb] bg-[#edf3e4] p-6 shadow-sm">
            <div className="flex items-center gap-3">
              <ShieldCheck className="h-5 w-5 text-[#506146]" />
              <h2 className="font-display text-xl text-[#20271b]">Privacy</h2>
            </div>
            <p className="mt-4 text-sm leading-6 text-[#485343]">
              Planner is a read-only Google Calendar client. It does not operate a developer-owned backend for your
              event data.
            </p>
            <Link
              className="mt-5 inline-flex items-center rounded-full border border-[#aab69b] bg-white px-4 py-2 text-sm font-medium text-[#2b3525] transition hover:bg-[#f8faf3]"
              to="/privacy"
            >
              Read Privacy Policy
            </Link>
          </article>
        </section>

        <section className="grid gap-4 sm:grid-cols-2">
          <article className="rounded-[24px] border border-[#c8d2bb] bg-white/90 p-6 shadow-sm">
            <div className="flex items-center gap-3">
              <MessageSquareWarning className="h-5 w-5 text-[#506146]" />
              <h2 className="font-display text-xl text-[#20271b]">Common issues</h2>
            </div>
            <ul className="mt-4 space-y-3 text-sm leading-6 text-[#485343]">
              <li>Google connection fails: check that Safari is enabled and your internet connection is active.</li>
              <li>Events do not appear: reconnect Google Calendar or pull to refresh after sign-in.</li>
              <li>Offline mode: Planner can show previously loaded events, but new events require a connection.</li>
            </ul>
          </article>

          <article className="rounded-[24px] border border-[#c8d2bb] bg-white/90 p-6 shadow-sm">
            <h2 className="font-display text-xl text-[#20271b]">Additional links</h2>
            <div className="mt-4 flex flex-col gap-3 text-sm">
              <Link
                className="inline-flex w-fit items-center rounded-full border border-[#aab69b] bg-[#f7f9f2] px-4 py-2 font-medium text-[#2b3525] transition hover:bg-white"
                to="/terms"
              >
                Terms of Service
              </Link>
              <a
                className="inline-flex w-fit items-center rounded-full border border-[#aab69b] bg-[#f7f9f2] px-4 py-2 font-medium text-[#2b3525] transition hover:bg-white"
                href="https://github.com/yet-an-other/planner/issues"
                rel="noreferrer"
                target="_blank"
              >
                GitHub issue tracker
              </a>
              <Link
                className="inline-flex w-fit items-center rounded-full border border-[#aab69b] bg-[#f7f9f2] px-4 py-2 font-medium text-[#2b3525] transition hover:bg-white"
                to="/year"
              >
                Open Planner
              </Link>
            </div>
          </article>
        </section>
      </div>
    </main>
  )
}
