import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { MapContainer, Marker, Popup, TileLayer } from 'react-leaflet';
import { useState } from 'react';
import api from '../api/client';

function parseLoc(raw: any) {
  if (!raw) return null;
  const lat = raw.latitude ?? raw._latitude ?? raw.lat;
  const lng = raw.longitude ?? raw._longitude ?? raw.lng;
  if (lat == null || lng == null) return null;
  return [lat, lng] as [number, number];
}

function statusBadge(status: string) {
  if (status === 'no_drivers') return 'badge-warning';
  if (status === 'completed') return 'badge-success';
  if (status === 'cancelled') return 'badge-muted';
  return 'badge-info';
}

export default function TripsPage() {
  const qc = useQueryClient();
  const [statusFilter, setStatusFilter] = useState('');

  const { data: liveData, isLoading: liveLoading } = useQuery({
    queryKey: ['trips-live'],
    queryFn: async () => (await api.get('/trips/live')).data,
  });

  const { data: allData, isLoading: allLoading } = useQuery({
    queryKey: ['trips-all', statusFilter],
    queryFn: async () => {
      const params = statusFilter ? `?status=${statusFilter}&limit=100` : '?limit=100';
      return (await api.get(`/trips${params}`)).data;
    },
  });

  const { data: driversData } = useQuery({
    queryKey: ['drivers-list'],
    queryFn: async () => (await api.get('/drivers')).data,
  });

  const cancelTrip = useMutation({
    mutationFn: (id: string) => api.post(`/trips/${id}/cancel`, { reason: 'Cancelled by admin' }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['trips-live'] });
      qc.invalidateQueries({ queryKey: ['trips-all'] });
    },
  });

  const assignDriver = useMutation({
    mutationFn: ({ tripId, driverId }: { tripId: string; driverId: string }) =>
      api.post(`/trips/${tripId}/assign-driver`, { driverId }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['trips-live'] });
      qc.invalidateQueries({ queryKey: ['trips-all'] });
    },
  });

  if (liveLoading || allLoading) return <p>Loading trips...</p>;

  const liveTrips = liveData?.trips || [];
  const trips = allData?.trips || [];
  const onlineDrivers = liveData?.drivers || [];
  const allDrivers = driversData?.drivers || [];
  const center = parseLoc(onlineDrivers[0]?.lastKnownLocation) || [18.4657, 73.8665];

  return (
    <div>
      <h1 className="page-title">Bookings & Live Map</h1>
      <div className="card" style={{ height: 360, marginBottom: 16, padding: 0, overflow: 'hidden' }}>
        <MapContainer center={center} zoom={12} style={{ height: '100%', width: '100%' }}>
          <TileLayer url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" />
          {onlineDrivers.map((d: any) => {
            const loc = parseLoc(d.lastKnownLocation);
            if (!loc) return null;
            return (
              <Marker key={d.id} position={loc}>
                <Popup>{d.name} (online)</Popup>
              </Marker>
            );
          })}
        </MapContainer>
      </div>

      <div className="card" style={{ marginBottom: 16 }}>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 12 }}>
          {['', 'pending', 'no_drivers', 'scheduled', 'accepted', 'in_progress', 'completed', 'cancelled'].map(
            (s) => (
              <button
                key={s || 'all'}
                className={`btn ${statusFilter === s ? 'btn-primary' : 'btn-secondary'}`}
                onClick={() => setStatusFilter(s)}
              >
                {s || 'all'}
              </button>
            ),
          )}
        </div>
        {trips.length === 0 ? (
          <p className="muted">No trips found. Book a ride from the rider app first.</p>
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>ID</th>
                <th>Status</th>
                <th>Pickup</th>
                <th>Dropoff</th>
                <th>Driver</th>
                <th>Offered</th>
                <th>Created</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {trips.map((t: any) => (
                <tr key={t.id}>
                  <td>{t.id.slice(0, 8)}...</td>
                  <td>
                    <span className={`badge ${statusBadge(t.status)}`}>{t.status}</span>
                  </td>
                  <td>{t.pickup}</td>
                  <td>{t.dropoff}</td>
                  <td>{t.driverId?.slice(0, 8) || '-'}</td>
                  <td>
                    {Array.isArray(t.offeredDriverIds) && t.offeredDriverIds.length > 0
                      ? `${t.offeredDriverIds.length} driver(s)`
                      : '-'}
                  </td>
                  <td>{t.createdAt ? new Date(t.createdAt).toLocaleString() : '-'}</td>
                  <td style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                    {['pending', 'no_drivers', 'scheduled'].includes(t.status) && (
                      <select
                        defaultValue=""
                        onChange={(e) => {
                          const driverId = e.target.value;
                          if (driverId) assignDriver.mutate({ tripId: t.id, driverId });
                          e.target.value = '';
                        }}
                      >
                        <option value="">Assign driver...</option>
                        {allDrivers
                          .filter((d: any) => d.isAvailable && d.documentStatus === 'approved')
                          .map((d: any) => (
                            <option key={d.id} value={d.id}>
                              {d.name || d.phone}
                            </option>
                          ))}
                      </select>
                    )}
                    {!['completed', 'cancelled'].includes(t.status) && (
                      <button className="btn btn-danger" onClick={() => cancelTrip.mutate(t.id)}>
                        Cancel
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {liveTrips.length > 0 && (
        <div className="card">
          <h3>Active on map query ({liveTrips.length})</h3>
          <p className="muted">Includes pending, no_drivers, scheduled, accepted, in_progress</p>
        </div>
      )}
    </div>
  );
}
