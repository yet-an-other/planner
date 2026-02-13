import { Navigate, Route, Routes } from 'react-router-dom'
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
      <Route element={<RedirectToCurrentYear />} path="/year" />
      <Route element={<YearPage />} path="/year/:year" />
      <Route element={<RedirectToCurrentYear />} path="*" />
    </Routes>
  )
}

export default App
