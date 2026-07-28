import { Navigate, Route, Routes } from 'react-router-dom';
import { useAuth } from './context/AuthContext';
import Layout from './components/Layout';
import LoginPage from './pages/LoginPage';
import DashboardPage from './pages/DashboardPage';
import DriversPage from './pages/DriversPage';
import CustomersPage from './pages/CustomersPage';
import TripsPage from './pages/TripsPage';
import PromosPage from './pages/PromosPage';
import PartnersPage from './pages/PartnersPage';
import SosPage from './pages/SosPage';
import TicketsPage from './pages/TicketsPage';
import PayoutsPage from './pages/PayoutsPage';
import NotificationsPage from './pages/NotificationsPage';
import AnalyticsPage from './pages/AnalyticsPage';
import ScheduledPage from './pages/ScheduledPage';

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { user, admin, otpVerified, loading } = useAuth();
  if (loading) return <p style={{ padding: 24 }}>Loading...</p>;
  if (!user || !admin) return <Navigate to="/login" replace />;
  if (!otpVerified) return <Navigate to="/login" replace />;
  return <>{children}</>;
}

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route
        path="/"
        element={
          <ProtectedRoute>
            <Layout />
          </ProtectedRoute>
        }
      >
        <Route index element={<DashboardPage />} />
        <Route path="drivers" element={<DriversPage />} />
        <Route path="customers" element={<CustomersPage />} />
        <Route path="trips" element={<TripsPage />} />
        <Route path="promos" element={<PromosPage />} />
        <Route path="partners" element={<PartnersPage />} />
        <Route path="sos" element={<SosPage />} />
        <Route path="tickets" element={<TicketsPage />} />
        <Route path="payouts" element={<PayoutsPage />} />
        <Route path="notifications" element={<NotificationsPage />} />
        <Route path="analytics" element={<AnalyticsPage />} />
        <Route path="scheduled" element={<ScheduledPage />} />
      </Route>
    </Routes>
  );
}
