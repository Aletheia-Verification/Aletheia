import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import MainLayout from './layouts/MainLayout';
import HomePage from './pages/HomePage';
import AnalyzePage from './pages/AnalyzePage';
import VerifyPage from './pages/VerifyPage';
import PortfolioPage from './pages/PortfolioPage';
import CompilerMatrixPage from './pages/CompilerMatrixPage';
import DeadCodePage from './pages/DeadCodePage';
import SBOMPage from './pages/SBOMPage';
import JCLPage from './pages/JCLPage';
import TracePage from './pages/TracePage';
import LandingPage from './pages/LandingPage';
import ErrorBoundary from './components/ErrorBoundary';

function App() {
    return (
        <ErrorBoundary>
        <BrowserRouter>
            <Routes>
                <Route path="/" element={<LandingPage />} />
                <Route path="/home" element={<HomePage />} />
                <Route element={<MainLayout />}>
                    <Route path="/analyze" element={<AnalyzePage />} />
                    <Route path="/verify" element={<VerifyPage />} />
                    <Route path="/trace" element={<TracePage />} />
                    <Route path="/portfolio" element={<PortfolioPage />} />
                    <Route path="/compiler-matrix" element={<CompilerMatrixPage />} />
                    <Route path="/dead-code" element={<DeadCodePage />} />
                    <Route path="/sbom" element={<SBOMPage />} />
                    <Route path="/jcl" element={<JCLPage />} />
                    <Route path="/login" element={<Navigate to="/analyze" replace />} />
                </Route>
                <Route path="*" element={<Navigate to="/" replace />} />
            </Routes>
        </BrowserRouter>
        </ErrorBoundary>
    );
}

export default App;
