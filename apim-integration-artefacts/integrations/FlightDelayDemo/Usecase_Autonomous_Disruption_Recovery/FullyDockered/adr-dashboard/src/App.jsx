import { Routes, Route, Navigate } from 'react-router-dom';
import Layout from './components/Layout';
import ProtectedRoute from './components/ProtectedRoute';
import AuthTokenProvider from './components/AuthTokenProvider';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import Flights from './pages/Flights';
import FlightDetail from './pages/FlightDetail';
import Disruptions from './pages/Disruptions';
import CrewMembers from './pages/CrewMembers';
import Passengers from './pages/Passengers';
import Logistics from './pages/Logistics';
import Recovery from './pages/Recovery';
import RecoveryPlanDetail from './pages/RecoveryPlanDetail';
import AIChat from './pages/AIChat';
import CustomerServiceChat from './pages/CustomerServiceChat';

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route
        path="/*"
        element={
          <ProtectedRoute>
            <AuthTokenProvider>
              <Layout>
                <Routes>
                  <Route path="/" element={<Dashboard />} />
                  <Route path="/flights" element={<Flights />} />
                  <Route path="/flights/:id" element={<FlightDetail />} />
                  <Route path="/disruptions" element={<Disruptions />} />
                  <Route path="/crew" element={<CrewMembers />} />
                  <Route path="/passengers/:flightId" element={<Passengers />} />
                  <Route path="/logistics" element={<Logistics />} />
                  <Route path="/recovery" element={<Recovery />} />
                  <Route path="/recovery/:id" element={<RecoveryPlanDetail />} />
                  <Route path="/ai-chat" element={<AIChat />} />
                  <Route path="/cs-chat" element={<CustomerServiceChat />} />
                  <Route path="*" element={<Navigate to="/" replace />} />
                </Routes>
              </Layout>
            </AuthTokenProvider>
          </ProtectedRoute>
        }
      />
    </Routes>
  );
}
