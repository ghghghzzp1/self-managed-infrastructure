import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import './GroupwareLogin.css';

function LockIcon() {
  return (
    <svg
      className="lock-icon"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
      <path d="M7 11V7a5 5 0 0 1 10 0v4" />
    </svg>
  );
}

function GroupwareLogin() {
  const navigate = useNavigate();
  const [id, setId] = useState('');
  const [password, setPassword] = useState('');

  const handleLogin = (e) => {
    e.preventDefault();
    // API 연결 전 - UI만
  };

  const handleSignUp = () => {
    navigate('/signup');
  };

  const handleMyInfo = () => {
    navigate('/myinfo');
  };

  return (
    <div className="groupware-login">
      <div className="login-card">
        <div className="login-icon-wrap">
          <LockIcon />
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
          <button
            type="button"
            className="btn btn-secondary"
            onClick={handleMyInfo}
          >
            내 정보 조회
          </button>
        </div>

        <p className="login-note">UI only - API not connected.</p>
      </div>
    </div>
  );
}

export default GroupwareLogin;
