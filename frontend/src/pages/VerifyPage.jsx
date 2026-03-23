import { useNavigate } from 'react-router-dom';
import ShadowDiff from '../components/ShadowDiff';

// Audited: ShadowDiff.jsx only calls onNavigate('engine') at line 657
const navMap = { vault: '/reports', engine: '/analyze' };

const VerifyPage = () => {
    const navigate = useNavigate();
    return <ShadowDiff onNavigate={(view) => navigate(navMap[view] || '/dashboard')} />;
};

export default VerifyPage;
