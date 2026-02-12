import { useNavigate } from 'react-router-dom';
import './Home.css';

function Home() {
  const navigate = useNavigate();

  const handleMyInfo = () => {
    navigate('/myinfo');
  };

  const handleLogout = () => {
    navigate('/');
  };

  return (
    <div className="groupware-page home-page">
      <div className="page-card">
        <h1 className="page-title">Exit8 Groupware</h1>
        <p className="page-subtitle">로그인되었습니다</p>

        <div className="home-actions">
          <button
            type="button"
            className="btn btn-primary"
            onClick={handleMyInfo}
          >
            내 정보 조회
          </button>
          <button
            type="button"
            className="btn btn-secondary"
            onClick={handleLogout}
          >
            로그아웃
          </button>
        </div>
      </div>
    </div>
  );
}

export default Home;
