import { useState } from 'react'

function App() {
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [message, setMessage] = useState('')

  const handleLogin = async (e) => {
    e.preventDefault()
    try {
      const res = await fetch(`/api/login?username=${username}&password=${password}`, {
        method: 'POST',
      })
      const data = await res.json()
      setMessage(data.message)
    } catch (err) {
      setMessage('Login failed')
    }
  }

  return (
    <div style={{
      display: 'flex',
      justifyContent: 'center',
      alignItems: 'center',
      minHeight: '100vh',
      fontFamily: 'system-ui'
    }}>
      <form onSubmit={handleLogin} style={{ width: 300 }}>
        <h1>Exit8 Login</h1>
        <div style={{ marginBottom: '1rem' }}>
          <input
            type="text"
            placeholder="Username"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            style={{ width: '100%', padding: '0.5rem' }}
          />
        </div>
        <div style={{ marginBottom: '1rem' }}>
          <input
            type="password"
            placeholder="Password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            style={{ width: '100%', padding: '0.5rem' }}
          />
        </div>
        <button type="submit" style={{ width: '100%', padding: '0.5rem' }}>
          Login
        </button>
        {message && <p>{message}</p>}
      </form>
    </div>
  )
}

export default App
