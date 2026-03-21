import { BrowserRouter, Routes, Route, NavLink } from 'react-router-dom'
import UploadPage from './pages/UploadPage'
import CandidatesPage from './pages/CandidatesPage'
import RecommendPage from './pages/RecommendPage'

function NavBar() {
  const linkClass = ({ isActive }) =>
    `px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
      isActive
        ? 'bg-blue-600 text-white'
        : 'text-gray-600 hover:bg-gray-100'
    }`
  return (
    <nav className="border-b border-gray-200 bg-white sticky top-0 z-10">
      <div className="max-w-4xl mx-auto px-4 py-3 flex items-center gap-2">
        <span className="font-semibold text-gray-800 mr-4">HR Recommender</span>
        <NavLink to="/" end className={linkClass}>Upload Resume</NavLink>
        <NavLink to="/candidates" className={linkClass}>Candidates</NavLink>
        <NavLink to="/recommend" className={linkClass}>JD Match</NavLink>
      </div>
    </nav>
  )
}

export default function App() {
  return (
    <BrowserRouter>
      <div className="min-h-screen bg-gray-50">
        <NavBar />
        <Routes>
          <Route path="/" element={<UploadPage />} />
          <Route path="/candidates" element={<CandidatesPage />} />
          <Route path="/recommend" element={<RecommendPage />} />
        </Routes>
      </div>
    </BrowserRouter>
  )
}
