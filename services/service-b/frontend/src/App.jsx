import { Routes, Route } from 'react-router-dom';
import GroupwareLogin from './components/GroupwareLogin';
import SignUp from './components/SignUp';
import MyInfo from './components/MyInfo';
import './App.css';

function App() {
  return (
    <div className="app">
      <Routes>
        <Route path="/" element={<GroupwareLogin />} />
        <Route path="/signup" element={<SignUp />} />
        <Route path="/myinfo" element={<MyInfo />} />
      </Routes>
    </div>
  );
}

export default App;
