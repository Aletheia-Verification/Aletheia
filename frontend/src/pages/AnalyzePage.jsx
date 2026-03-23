import { useNavigate } from 'react-router-dom';
import Engine from '../components/Engine';

// Audited: Engine.jsx only calls onNavigate('vault') at line 1012
const navMap = { vault: '/reports', engine: '/analyze' };

const AnalyzePage = () => {
    const navigate = useNavigate();
    return <Engine onNavigate={(view) => navigate(navMap[view] || '/dashboard')} />;
};

export default AnalyzePage;
