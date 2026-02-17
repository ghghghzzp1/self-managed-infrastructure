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
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState('');

  const handleLogin = async (e) => {
    e.preventDefault();
    setErrorMessage('');

    const username = id.trim();
    if (!username || !password) {
      setErrorMessage('아이디와 비밀번호를 입력해주세요.');
      return;
    }

    setIsLoading(true);
    try {
      const res = await fetch('/api/v1/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, password }),
      });

      const payload = await res.json().catch(() => null);

      if (!res.ok) {
        const msg =
          payload?.error?.message ||
          (res.status === 401 ? '아이디 또는 비밀번호가 올바르지 않습니다.' : '로그인에 실패했습니다.');
        setErrorMessage(msg);
        return;
      }

      // 기대 응답 형태: { success: 200, data: { id, username, name, email, is_admin }, error: null }
      const user = payload?.data ?? null;
      if (!user?.id) {
        setErrorMessage('로그인 응답을 처리할 수 없습니다.');
        return;
      }

      localStorage.setItem('service-b.user', JSON.stringify(user));
      navigate('/home');
    } catch (err) {
      setErrorMessage('네트워크 오류로 로그인에 실패했습니다.');
    } finally {
      setIsLoading(false);
    }
  };

  const handleSignUp = () => {
    navigate('/signup');
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
          <button type="submit" className="btn btn-primary" disabled={isLoading}>
            {isLoading ? '로그인 중...' : '로그인'}
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

        {errorMessage ? (
          <p className="login-note" role="alert">
            {errorMessage}
          </p>
        ) : (
          <p className="login-note">로그인 API 연결 완료</p>
        )}
      </div>
    </div>
  );
}

export default GroupwareLogin;
