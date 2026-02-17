import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import './SignUp.css';

function SignUp() {
  const navigate = useNavigate();
  const [username, setUsername] = useState('');
  const [name, setName] = useState('');
  const [password, setPassword] = useState('');
  const [email, setEmail] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState('');
  const [successMessage, setSuccessMessage] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    setErrorMessage('');
    setSuccessMessage('');

    const payload = {
      username: username.trim(),
      name: name.trim(),
      password,
      email: email.trim(),
    };

    if (!payload.username || !payload.name || !payload.password || !payload.email) {
      setErrorMessage('모든 항목을 입력해주세요.');
      return;
    }

    setIsLoading(true);
    try {
      const res = await fetch('/api/v1/auth/register', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });

      const data = await res.json().catch(() => null);

      if (!res.ok) {
        const msg =
          data?.message ||
          data?.error?.message ||
          (res.status === 400 ? '회원가입에 실패했습니다. 입력값을 확인해주세요.' : '회원가입에 실패했습니다.');
        setErrorMessage(msg);
        return;
      }

      // 기대 응답 형태: { success: 201, data: { username, message }, error: null }
      const msg = data?.data?.message || '회원가입이 완료되었습니다. 로그인해주세요.';
      setSuccessMessage(msg);
      // 성공 시 로그인 화면으로 이동
      navigate('/');
    } catch (err) {
      setErrorMessage('네트워크 오류로 회원가입에 실패했습니다.');
    } finally {
      setIsLoading(false);
    }
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
            {isLoading ? '처리 중...' : '회원가입'}
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

        {errorMessage ? (
          <p className="page-note" role="alert">
            {errorMessage}
          </p>
        ) : successMessage ? (
          <p className="page-note">{successMessage}</p>
        ) : (
          <p className="page-note">회원가입 API 연결 완료</p>
        )}
      </div>
    </div>
  );
}

export default SignUp;
