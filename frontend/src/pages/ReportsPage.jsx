import { useNavigate } from 'react-router-dom';
import Vault from '../components/Vault';

// Audited: Vault.jsx calls onNavigate('engine') at lines 217 and 308
const navMap = { vault: '/reports', engine: '/analyze' };

const ReportsPage = () => {
    const navigate = useNavigate();
    return <Vault onNavigate={(view) => navigate(navMap[view] || '/dashboard')} />;
};

export default ReportsPage;
