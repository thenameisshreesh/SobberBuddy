import { useQuery } from '@tanstack/react-query';
import api from '../api/client';

export default function AnalyticsPage() {
  const { data, isLoading } = useQuery({
    queryKey: ['analytics-summary'],
    queryFn: async () => (await api.get('/analytics/summary')).data,
  });

  if (isLoading) return <p>Loading analytics...</p>;

  return (
    <div>
      <h1 className="page-title">Analytics</h1>
      <div className="grid-4">
        <div className="card"><div className="muted">Total Revenue</div><div style={{ fontSize: 24 }}>₹{Math.round(data.totalRevenue || 0)}</div></div>
        <div className="card"><div className="muted">Completed Trips</div><div style={{ fontSize: 24 }}>{data.completedTrips}</div></div>
        <div className="card"><div className="muted">Active Trips</div><div style={{ fontSize: 24 }}>{data.activeTrips}</div></div>
        <div className="card"><div className="muted">Driver Utilization</div><div style={{ fontSize: 24 }}>{data.onlineDrivers}/{data.totalDrivers}</div></div>
      </div>
    </div>
  );
}
