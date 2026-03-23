import { useState, useRef } from 'react'

export default function RecommendPage() {
  const [jdText, setJdText] = useState('')
  const [limit, setLimit] = useState(10)
  const [results, setResults] = useState(null)
  const [loading, setLoading] = useState(false)
  const [uploading, setUploading] = useState(false)
  const [error, setError] = useState(null)
  const fileInputRef = useRef(null)

  async function handleFileUpload(e) {
    const file = e.target.files?.[0]
    if (!file) return
    setUploading(true)
    setError(null)
    try {
      const formData = new FormData()
      formData.append('file', file)
      const res = await fetch('/api/jd/upload-file', { method: 'POST', body: formData })
      if (!res.ok) throw new Error(`File upload failed — HTTP ${res.status}`)
      const data = await res.json()
      setJdText(data.text || '')
    } catch (err) {
      setError(err.message)
    } finally {
      setUploading(false)
      // reset so the same file can be re-selected
      if (fileInputRef.current) fileInputRef.current.value = ''
    }
  }

  async function handleSubmit(e) {
    e.preventDefault()
    if (!jdText.trim()) return
    setLoading(true)
    setError(null)
    setResults(null)
    try {
      // Step 1: analyze JD
      const jdRes = await fetch('/api/jd/analyze', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: jdText.trim() }),
      })
      if (!jdRes.ok) throw new Error(`JD analysis failed — HTTP ${jdRes.status}`)
      const jd = await jdRes.json()

      // Step 2: recommend
      const recRes = await fetch(`/api/recommend?jdId=${jd.jdId}&limit=${limit}`)
      if (!recRes.ok) throw new Error(`Recommend API failed — HTTP ${recRes.status}`)
      const rec = await recRes.json()
      setResults({ jd, rec })
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="max-w-3xl mx-auto py-10 px-4">
      <h1 className="text-2xl font-semibold text-gray-800 mb-6">JD Match & Recommend</h1>

      <form onSubmit={handleSubmit} className="space-y-4">
        {/* File upload zone */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Upload JD File (optional)</label>
          <label
            className={`flex items-center justify-center gap-2 w-full border-2 border-dashed rounded-lg px-4 py-4 cursor-pointer transition-colors
              ${uploading ? 'border-blue-300 bg-blue-50' : 'border-gray-200 hover:border-blue-300 hover:bg-blue-50'}`}
          >
            <input
              ref={fileInputRef}
              type="file"
              accept=".pdf,.docx"
              className="hidden"
              onChange={handleFileUpload}
              disabled={uploading}
            />
            {uploading ? (
              <span className="text-sm text-blue-600">Extracting text from file...</span>
            ) : (
              <span className="text-sm text-gray-500">
                Drop a <span className="font-medium">.pdf</span> or <span className="font-medium">.docx</span> file here, or click to browse — text will auto-fill below
              </span>
            )}
          </label>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Job Description</label>
          <textarea
            value={jdText}
            onChange={e => setJdText(e.target.value)}
            placeholder="Paste the job description here, or upload a file above..."
            rows={8}
            className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 resize-none"
          />
        </div>
        <div className="flex items-center gap-3">
          <label className="text-sm font-medium text-gray-700">Top N results</label>
          <input
            type="number"
            min={1}
            max={50}
            value={limit}
            onChange={e => setLimit(Number(e.target.value))}
            className="w-20 border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
        <button
          type="submit"
          disabled={loading || !jdText.trim()}
          className="w-full bg-blue-600 text-white py-2 rounded-lg text-sm font-medium hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
        >
          {loading ? 'Analysing...' : 'Analyse & Recommend'}
        </button>
      </form>

      {error && (
        <div className="mt-4 p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700">{error}</div>
      )}

      {results && (
        <div className="mt-6 space-y-4">
          <div className="p-4 bg-blue-50 border border-blue-200 rounded-xl text-sm">
            <p className="font-medium text-blue-800 mb-1">JD Analysis (id: {results.jd.jdId})</p>
            <p className="text-blue-700">{results.jd.summary || '(No summary generated)'}</p>
            <div className="mt-2 flex flex-wrap gap-1">
              {results.jd.requiredSkills?.map(s => (
                <span key={s} className="px-2 py-0.5 bg-blue-100 text-blue-700 rounded-full text-xs">{s}</span>
              ))}
            </div>
          </div>

          <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
            <div className="px-4 py-3 border-b border-gray-100 text-sm font-medium text-gray-700">
              Recommended Candidates ({results.rec.total})
            </div>
            <table className="w-full text-sm">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="text-left px-4 py-2 font-medium text-gray-600">Candidate</th>
                  <th className="text-left px-4 py-2 font-medium text-gray-600">Match Score</th>
                  <th className="text-left px-4 py-2 font-medium text-gray-600">Top Gaps</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {results.rec.results.length === 0 ? (
                  <tr>
                    <td colSpan={3} className="px-4 py-6 text-center text-gray-400">No candidates found</td>
                  </tr>
                ) : results.rec.results.map((r, i) => (
                  <tr key={r.documentId} className="hover:bg-gray-50">
                    <td className="px-4 py-3">
                      <span className="font-medium text-gray-800">{r.candidateId}</span>
                      <span className="ml-2 text-xs text-gray-400">#{r.documentId}</span>
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-2">
                        <div className="w-24 h-2 bg-gray-100 rounded-full overflow-hidden">
                          <div
                            className="h-full bg-blue-500 rounded-full"
                            style={{ width: `${Math.round(r.score * 100)}%` }}
                          />
                        </div>
                        <span className="text-xs text-gray-600 font-mono">{(r.score * 100).toFixed(1)}%</span>
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex flex-wrap gap-1">
                        {r.topGaps.slice(0, 3).map(g => (
                          <span key={g.canonical} className="px-1.5 py-0.5 bg-red-50 text-red-600 rounded text-xs">
                            {g.canonical.replace('skill/', '')}
                          </span>
                        ))}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  )
}
