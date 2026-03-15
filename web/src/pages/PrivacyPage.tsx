import { Link } from 'react-router-dom'

export function PrivacyPage() {
  return (
    <main className="min-h-screen px-4 py-8 sm:px-6 sm:py-10">
      <div className="mx-auto flex max-w-4xl flex-col gap-6">
        <header className="rounded-[28px] border border-[#bcc8a8]/70 bg-[#f5f7ef]/95 p-6 shadow-[0_18px_50px_rgba(88,98,56,0.12)] sm:p-8">
          <p className="font-display text-xs uppercase tracking-[0.22em] text-[#5c6c52]">Planner Privacy Policy</p>
          <h1 className="mt-3 font-display text-3xl text-[#1f2618] sm:text-4xl">Privacy</h1>
          <p className="mt-4 text-sm leading-6 text-[#46523f] sm:text-base">
            Effective date: March 13, 2026
          </p>
        </header>

        <article className="rounded-[24px] border border-[#c8d2bb] bg-white/92 p-6 text-sm leading-7 text-[#485343] shadow-sm sm:p-8">
          <p>
            Planner is a read-only Google Calendar client. If you choose to connect Google Calendar, the app requests
            access to your basic Google account identity and your Google Calendar data so it can display your events.
          </p>

          <h2 className="mt-6 font-display text-xl text-[#20271b]">What Planner stores</h2>
          <p className="mt-2">
            Planner stores your Google session in the iOS Keychain and stores your profile information, cached events,
            and the last successful refresh timestamp locally on your device.
          </p>

          <h2 className="mt-6 font-display text-xl text-[#20271b]">What Planner does not do</h2>
          <p className="mt-2">
            Planner does not create, edit, or delete Google Calendar events. Planner does not run a developer-owned
            backend for your calendar data, and it does not use advertising SDKs or behavioral tracking for ads.
          </p>

          <h2 className="mt-6 font-display text-xl text-[#20271b]">Third-party services</h2>
          <p className="mt-2">
            Planner connects directly to Google services for account connection and calendar loading, including
            accounts.google.com, oauth2.googleapis.com, openidconnect.googleapis.com, and www.googleapis.com.
          </p>

          <h2 className="mt-6 font-display text-xl text-[#20271b]">Your choices</h2>
          <p className="mt-2">
            You can disconnect your Google account from Planner at any time, revoke access from your Google account
            settings, or delete the app to remove locally stored app data from your device.
          </p>

          <h2 className="mt-6 font-display text-xl text-[#20271b]">Contact</h2>
          <p className="mt-2">
            For privacy questions, contact{' '}
            <a className="font-medium text-[#385f3a] underline underline-offset-4" href="mailto:main@ivan-b.com">
              main@ivan-b.com
            </a>
            .
          </p>

          <div className="mt-8">
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
