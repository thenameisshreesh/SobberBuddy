import { NavLink, Outlet } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import './Layout.css';

const links = [
  { to: '/', label: 'Dashboard' },
  { to: '/drivers', label: 'Drivers' },
  { to: '/customers', label: 'Customers' },
  { to: '/trips', label: 'Bookings' },
  { to: '/scheduled', label: 'Scheduled' },
  { to: '/promos', label: 'Promos' },
  { to: '/partners', label: 'Partners' },
  { to: '/sos', label: 'SOS' },
  { to: '/tickets', label: 'Support' },
  { to: '/payouts', label: 'Payouts' },
  { to: '/notifications', label: 'Notifications' },
  { to: '/analytics', label: 'Analytics' },
];

export default function Layout() {
  const { admin, logout } = useAuth();

  return (
    <div className="layout">
      <aside className="sidebar">
        <div className="brand">
          <span className="brand-dot driver" />
          <span className="brand-dot rider" />
          <div>
            <strong>SoberBuddy</strong>
            <div className="muted">Admin Console</div>
          </div>
        </div>
        <nav>
          {links.map((link) => (
            <NavLink key={link.to} to={link.to} end={link.to === '/'} className={({ isActive }) => (isActive ? 'nav-link active' : 'nav-link')}>
              {link.label}
            </NavLink>
          ))}
        </nav>
        <div className="sidebar-footer">
          <div className="muted">{admin?.email}</div>
          <button className="btn btn-secondary" onClick={() => logout()}>Logout</button>
        </div>
      </aside>
      <main className="content">
        <Outlet />
      </main>
    </div>
  );
}
