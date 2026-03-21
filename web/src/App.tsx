import { Navigate, Route, Routes } from 'react-router-dom'
import { PrivacyPage } from './pages/PrivacyPage'
import { SupportPage } from './pages/SupportPage'
import { TermsPage } from './pages/TermsPage'
import { YearPage } from './pages/YearPage'

function currentYearPath() {
  return `/year/${new Date().getFullYear()}`
}

function RedirectToCurrentYear() {
  return <Navigate replace to={currentYearPath()} />
}

function App() {
  return (
    <Routes>
      <Route element={<RedirectToCurrentYear />} path="/" />
      <Route element={<SupportPage />} path="/support" />
      <Route element={<PrivacyPage />} path="/privacy" />
      <Route element={<TermsPage />} path="/terms" />
      <Route element={<RedirectToCurrentYear />} path="/year" />
      <Route element={<YearPage />} path="/year/:year" />
      <Route element={<RedirectToCurrentYear />} path="*" />
    </Routes>
  )
}

export default App
