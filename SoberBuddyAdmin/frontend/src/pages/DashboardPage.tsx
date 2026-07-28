import { useQuery } from '@tanstack/react-query';
import api from '../api/client';

export default function DashboardPage() {
  const { data, isLoading } = useQuery({
    queryKey: ['analytics-summary'],
    queryFn: async () => (await api.get('/analytics/summary')).data,
  });

  if (isLoading) return <p>Loading dashboard...</p>;

  const cards = [
    { label: 'Active Trips', value: data?.activeTrips ?? 0 },
    { label: 'Completed Trips', value: data?.completedTrips ?? 0 },
    { label: 'Online Drivers', value: data?.onlineDrivers ?? 0 },
    { label: 'Total Customers', value: data?.totalCustomers ?? 0 },
    { label: 'Open SOS', value: data?.openSos ?? 0 },
    { label: 'Open Tickets', value: data?.openTickets ?? 0 },
    { label: 'Revenue (INR)', value: Math.round(data?.totalRevenue ?? 0) },
  ];

  return (
    <div>
      <h1 className="page-title">Dashboard</h1>
      <div className="grid-4">
        {cards.map((card) => (
          <div key={card.label} className="card">
            <div className="muted">{card.label}</div>
            <div style={{ fontSize: 28, fontWeight: 700 }}>{card.value}</div>
          </div>
        ))}
      </div>
    </div>
  );
}
