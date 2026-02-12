import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import './GroupwareLogin.css';

function LIcon() {
  return (
    <svg
      className="l-icon"
      viewBox="0 0 24 24"
      fill="currentColor"
    >
      <path d="M8 4h4v14H8V4zm0 14h10v-3H8v3z" />
    </svg>
  );
}

function GroupwareLogin() {
  const navigate = useNavigate();
  const [id, setId] = useState('');
  const [password, setPassword] = useState('');

  const handleLogin = (e) => {
    e.preventDefault();
    // API 연결 전 - 로그인 성공 시 홈으로 이동 (UI만)
    navigate('/home');
  };

  const handleSignUp = () => {
    navigate('/signup');
  };

  return (
    <div className="groupware-login">
      <div className="login-card">
        <div className="login-icon-wrap">
          <LIcon />
        </div>
        <h1 className="login-title">Exit8 Groupware</h1>
        <p className="login-subtitle">사내 문서 관리 시스템 로그인</p>

        <form className="login-form" onSubmit={handleLogin}>
          <input
            type="text"
            className="login-input"
            placeholder="아이디를 입력하세요"
            value={id}
            onChange={(e) => setId(e.target.value)}
            autoComplete="username"
          />
          <input
            type="password"
            className="login-input"
            placeholder="비밀번호"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete="current-password"
          />
          <button type="submit" className="btn btn-primary">
            로그인
          </button>
        </form>

        <div className="login-actions">
          <button
            type="button"
            className="btn btn-secondary"
            onClick={handleSignUp}
          >
            회원가입
          </button>
        </div>

        <p className="login-note">UI only - API not connected.</p>
      </div>
    </div>
  );
}

export default GroupwareLogin;
