import { useState, useEffect } from 'react'

function SeniorityBadge({ level }) {
  if (!level) return null
  const styles = {
    Junior: 'bg-blue-100 text-blue-700',
    Mid: 'bg-yellow-100 text-yellow-700',
    Senior: 'bg-green-100 text-green-700',
  }
  return (
    <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${styles[level] || 'bg-gray-100 text-gray-600'}`}>
      {level}
    </span>
  )
}

export default function CandidatesPage() {
  const [candidates, setCandidates] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  useEffect(() => {
    fetch('/api/candidates?limit=50')
      .then(r => r.ok ? r.json() : Promise.reject(`HTTP ${r.status}`))
      .then(data => setCandidates(data))
      .catch(err => setError(String(err)))
      .finally(() => setLoading(false))
  }, [])

  return (
    <div className="max-w-4xl mx-auto py-10 px-4">
      <h1 className="text-2xl font-semibold text-gray-800 mb-6">Candidates</h1>

      {loading && <p className="text-sm text-gray-500">Loading...</p>}
      {error && (
        <div className="p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700">{error}</div>
      )}

      {!loading && !error && (
        <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Document ID</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Candidate ID</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Seniority</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Type</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Created At</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {candidates.length === 0 ? (
                <tr>
                  <td colSpan={5} className="px-4 py-8 text-center text-gray-400">No data</td>
                </tr>
              ) : candidates.map(c => (
                <tr key={c.documentId} className="hover:bg-gray-50 transition-colors">
                  <td className="px-4 py-3 font-mono text-blue-600">{c.documentId}</td>
                  <td className="px-4 py-3 text-gray-800">{c.candidateId}</td>
                  <td className="px-4 py-3">
                    <SeniorityBadge level={c.seniorityLevel} />
                  </td>
                  <td className="px-4 py-3 text-gray-500">{c.entityType}</td>
                  <td className="px-4 py-3 text-gray-400 text-xs">{new Date(c.createdAt).toLocaleString('en-AU')}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
