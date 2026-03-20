import { Link } from 'react-router-dom'

export function TermsPage() {
  return (
    <main className="min-h-screen px-4 py-8 sm:px-6 sm:py-10">
      <div className="mx-auto flex max-w-4xl flex-col gap-6">
        <header className="rounded-[28px] border border-[#bcc8a8]/70 bg-[#f5f7ef]/95 p-6 shadow-[0_18px_50px_rgba(88,98,56,0.12)] sm:p-8">
          <p className="font-display text-xs uppercase tracking-[0.22em] text-[#5c6c52]">Planner Terms of Service</p>
          <h1 className="mt-3 font-display text-3xl text-[#1f2618] sm:text-4xl">Terms</h1>
          <p className="mt-4 text-sm leading-6 text-[#46523f] sm:text-base">
            Effective date: March 20, 2026
          </p>
        </header>

        <article className="rounded-[24px] border border-[#c8d2bb] bg-white/92 p-6 text-sm leading-7 text-[#485343] shadow-sm sm:p-8">
          <p>
            Planner is a read-only calendar viewer that helps you browse your Google Calendar data in a year layout.
            By using Planner, you agree to these Terms of Service.
          </p>

          <h2 className="mt-6 font-display text-xl text-[#20271b]">Use of the service</h2>
          <p className="mt-2">
            You may use Planner only in compliance with applicable laws and these terms. You are responsible for the
            Google account you choose to connect and for any activity that takes place on your device.
          </p>

          <h2 className="mt-6 font-display text-xl text-[#20271b]">Google account connection</h2>
          <p className="mt-2">
            Planner connects directly to Google so it can read your calendar data. Planner does not create, modify, or
            delete your Google Calendar events.
          </p>

          <h2 className="mt-6 font-display text-xl text-[#20271b]">Availability</h2>
          <p className="mt-2">
            Planner is provided on an as-is basis. Features may change, and service availability can depend on Google
            services, network access, and platform behavior outside the developer&apos;s control.
          </p>

          <h2 className="mt-6 font-display text-xl text-[#20271b]">Acceptable use</h2>
          <p className="mt-2">
            You must not use Planner to violate any laws, interfere with the service, reverse engineer the app in a
            prohibited way, or abuse Google services through the app.
          </p>

          <h2 className="mt-6 font-display text-xl text-[#20271b]">Third-party services</h2>
          <p className="mt-2">
            Planner relies on Google services for authentication and calendar access. Your use of those services
            remains subject to Google&apos;s own terms and policies.
          </p>

          <h2 className="mt-6 font-display text-xl text-[#20271b]">Contact</h2>
          <p className="mt-2">
            For terms questions, contact{' '}
            <a className="font-medium text-[#385f3a] underline underline-offset-4" href="mailto:main@ivan-b.com">
              main@ivan-b.com
            </a>
            .
          </p>

          <div className="mt-8 flex flex-wrap gap-3">
            <Link
              className="inline-flex items-center rounded-full border border-[#aab69b] bg-[#f7f9f2] px-4 py-2 font-medium text-[#2b3525] transition hover:bg-white"
              to="/privacy"
            >
              Privacy Policy
            </Link>
            <Link
              className="inline-flex items-center rounded-full border border-[#aab69b] bg-[#f7f9f2] px-4 py-2 font-medium text-[#2b3525] transition hover:bg-white"
              to="/support"
            >
              Back to support
            </Link>
          </div>
        </article>
      </div>
    </main>
  )
}
