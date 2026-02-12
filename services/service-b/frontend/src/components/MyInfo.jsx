import { useNavigate } from 'react-router-dom';
import './MyInfo.css';

function MyInfo() {
  const navigate = useNavigate();

  const handleBackToLogin = () => {
    navigate('/');
  };

  return (
    <div className="groupware-page myinfo-page">
      <div className="page-card">
        <h1 className="page-title">내 정보</h1>
        <p className="page-subtitle">로그인한 사용자 정보를 확인합니다</p>

        <div className="myinfo-placeholder">
          <p>이름: -</p>
          <p>이메일: -</p>
          <p className="myinfo-hint">UI only - API not connected.</p>
        </div>

        <div className="page-actions">
          <button
            type="button"
            className="btn btn-primary"
            onClick={handleBackToLogin}
          >
            로그인으로 돌아가기
          </button>
        </div>
      </div>
    </div>
  );
}

export default MyInfo;
