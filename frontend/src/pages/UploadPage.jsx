import { useState } from 'react'

export default function UploadPage() {
  const [dragging, setDragging] = useState(false)
  const [file, setFile] = useState(null)
  const [candidateId, setCandidateId] = useState('')
  const [result, setResult] = useState(null)
  const [analysis, setAnalysis] = useState(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)

  function onDrop(e) {
    e.preventDefault()
    setDragging(false)
    const dropped = e.dataTransfer.files[0]
    if (dropped) setFile(dropped)
  }

  async function handleSubmit(e) {
    e.preventDefault()
    if (!file || !candidateId.trim()) return
    setLoading(true)
    setError(null)
    setResult(null)
    setAnalysis(null)
    try {
      const form = new FormData()
      form.append('file', file)
      form.append('candidateId', candidateId.trim())
      const res = await fetch(`/api/resumes/file?candidateId=${encodeURIComponent(candidateId.trim())}`, {
        method: 'POST',
        body: form,
      })
      if (!res.ok) throw new Error(`HTTP ${res.status}`)
      const ingestData = await res.json()
      setResult(ingestData)

      // Auto-trigger skill analysis
      const analyzeRes = await fetch(`/api/resumes/${ingestData.documentId}/analyze/bootstrap`, {
        method: 'POST',
      })
      if (!analyzeRes.ok) throw new Error(`Analysis failed — HTTP ${analyzeRes.status}`)
      setAnalysis(await analyzeRes.json())
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="max-w-xl mx-auto py-10 px-4">
      <h1 className="text-2xl font-semibold text-gray-800 mb-6">Upload Resume</h1>
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Candidate ID</label>
          <input
            type="text"
            value={candidateId}
            onChange={e => setCandidateId(e.target.value)}
            placeholder="e.g. fortune-xu"
            className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        <div
          onDragOver={e => { e.preventDefault(); setDragging(true) }}
          onDragLeave={() => setDragging(false)}
          onDrop={onDrop}
          onClick={() => document.getElementById('fileInput').click()}
          className={`border-2 border-dashed rounded-xl p-10 text-center cursor-pointer transition-colors
            ${dragging ? 'border-blue-500 bg-blue-50' : 'border-gray-300 hover:border-blue-400 bg-white'}`}
        >
          <input
            id="fileInput"
            type="file"
            accept=".pdf,.doc,.docx"
            className="hidden"
            onChange={e => setFile(e.target.files[0])}
          />
          {file ? (
            <p className="text-sm text-gray-700 font-medium">{file.name}</p>
          ) : (
            <>
              <p className="text-gray-500 text-sm">Drop a PDF or DOCX file here</p>
              <p className="text-gray-400 text-xs mt-1">or click to browse</p>
            </>
          )}
        </div>

        <button
          type="submit"
          disabled={loading || !file || !candidateId.trim()}
          className="w-full bg-blue-600 text-white py-2 rounded-lg text-sm font-medium hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
        >
          {loading
            ? (result ? 'Analysing skills...' : 'Uploading...')
            : 'Submit Resume'}
        </button>
      </form>

      {error && (
        <div className="mt-4 p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700">{error}</div>
      )}
      {result && (
        <div className="mt-4 p-3 bg-green-50 border border-green-200 rounded-lg text-sm text-green-700">
          Resume uploaded! Document ID: <span className="font-mono font-bold">{result.documentId}</span>
        </div>
      )}

      {analysis && analysis.keywords?.length > 0 && (
        <div className="mt-4 p-4 bg-white border border-gray-200 rounded-xl">
          <p className="text-sm font-medium text-gray-700 mb-3">
            Extracted Skills
            <span className="ml-2 text-xs font-normal text-gray-400">({analysis.keywords.length} tags)</span>
          </p>
          <div className="flex flex-wrap gap-2">
            {analysis.keywords.map((kw, i) => (
              <span
                key={i}
                title={`score: ${kw.score.toFixed(2)}${kw.evidence ? ` — "${kw.evidence}"` : ''}`}
                className="px-2.5 py-1 bg-blue-50 text-blue-700 border border-blue-200 rounded-full text-xs font-medium"
              >
                {kw.normalized || kw.term}
              </span>
            ))}
          </div>
        </div>
      )}

      {analysis && analysis.keywords?.length === 0 && (
        <div className="mt-4 p-3 bg-yellow-50 border border-yellow-200 rounded-lg text-sm text-yellow-700">
          No skill tags extracted. The extraction service may be unavailable.
        </div>
      )}
    </div>
  )
}
