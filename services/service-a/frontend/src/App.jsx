import { useState, useEffect } from 'react'

function App() {
  const [dashboardData, setDashboardData] = useState(null)

  useEffect(() => {
    fetch('/api/dashboard')
      .then(res => res.json())
      .then(data => setDashboardData(data))
      .catch(console.error)
  }, [])

  return (
    <div style={{ padding: '2rem', fontFamily: 'system-ui' }}>
      <h1>Exit8 Dashboard</h1>
      {dashboardData ? (
        <div>
          <p>Total Users: {dashboardData.data?.totalUsers}</p>
          <p>Active Users: {dashboardData.data?.activeUsers}</p>
        </div>
      ) : (
        <p>Loading...</p>
      )}
    </div>
  )
}

export default App
