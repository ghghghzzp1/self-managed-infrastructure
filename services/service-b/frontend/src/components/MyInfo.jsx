import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import './MyInfo.css';

function MyInfo() {
  const navigate = useNavigate();
  const [isLoading, setIsLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState('');
  const [profile, setProfile] = useState({ name: '-', email: '-' });

  const userId = useMemo(() => {
    try {
      const raw = localStorage.getItem('service-b.user');
      if (!raw) return null;
      const user = JSON.parse(raw);
      return typeof user?.id === 'number' ? user.id : Number(user?.id) || null;
    } catch {
      return null;
    }
  }, []);

  useEffect(() => {
    let cancelled = false;

    async function fetchProfile() {
      setIsLoading(true);
      setErrorMessage('');

      if (!userId) {
        setIsLoading(false);
        setErrorMessage('로그인 정보가 없습니다. 다시 로그인해주세요.');
        return;
      }

      try {
        const res = await fetch(`/api/v1/auth/profile/${userId}`, { method: 'GET' });
        const payload = await res.json().catch(() => null);

        if (!res.ok) {
          const msg = payload?.message || payload?.error?.message || '내 정보 조회에 실패했습니다.';
          if (!cancelled) setErrorMessage(msg);
          return;
        }

        const data = payload?.data;
        if (!data?.name || !data?.email) {
          if (!cancelled) setErrorMessage('내 정보 응답을 처리할 수 없습니다.');
          return;
        }

        if (!cancelled) setProfile({ name: data.name, email: data.email });
      } catch {
        if (!cancelled) setErrorMessage('네트워크 오류로 내 정보 조회에 실패했습니다.');
      } finally {
        if (!cancelled) setIsLoading(false);
      }
    }

    fetchProfile();
    return () => {
      cancelled = true;
    };
  }, [userId]);

  const handleBackToHome = () => {
    navigate('/home');
  };

  return (
    <div className="groupware-page myinfo-page">
      <div className="page-card">
        <h1 className="page-title">내 정보</h1>
        <p className="page-subtitle">로그인한 사용자 정보를 확인합니다</p>

        <div className="myinfo-placeholder">
          <p>이름: {profile.name}</p>
          <p>이메일: {profile.email}</p>
          {isLoading ? (
            <p className="myinfo-hint">조회 중...</p>
          ) : errorMessage ? (
            <p className="myinfo-hint" role="alert">
              {errorMessage}
            </p>
          ) : (
            <p className="myinfo-hint">내 정보 API 연결 완료</p>
          )}
        </div>

        <div className="page-actions">
          <button
            type="button"
            className="btn btn-primary"
            onClick={handleBackToHome}
          >
            홈으로
          </button>
        </div>
      </div>
    </div>
  );
}

export default MyInfo;
