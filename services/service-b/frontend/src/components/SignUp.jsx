import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import './SignUp.css';

function SignUp() {
  const navigate = useNavigate();
  const [username, setUsername] = useState('');
  const [name, setName] = useState('');
  const [password, setPassword] = useState('');
  const [email, setEmail] = useState('');

  const handleSubmit = (e) => {
    e.preventDefault();
    // API 연결 전 - UI만
  };

  const handleBackToLogin = () => {
    navigate('/');
  };

  return (
    <div className="groupware-page signup-page">
      <div className="page-card">
        <h1 className="page-title">회원가입</h1>
        <p className="page-subtitle">Exit8 Groupware 계정 생성</p>

        <form className="page-form" onSubmit={handleSubmit}>
          <input
            type="text"
            className="page-input"
            placeholder="아이디"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            autoComplete="username"
          />
          <input
            type="text"
            className="page-input"
            placeholder="실명"
            value={name}
            onChange={(e) => setName(e.target.value)}
            autoComplete="name"
          />
          <input
            type="password"
            className="page-input"
            placeholder="비밀번호"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete="new-password"
          />
          <input
            type="email"
            className="page-input"
            placeholder="이메일"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            autoComplete="email"
          />
          <button type="submit" className="btn btn-primary">
            회원가입
          </button>
        </form>

        <div className="page-actions">
          <button
            type="button"
            className="btn btn-secondary"
            onClick={handleBackToLogin}
          >
            로그인으로 돌아가기
          </button>
        </div>

        <p className="page-note">UI only - API not connected.</p>
      </div>
    </div>
  );
}

export default SignUp;
