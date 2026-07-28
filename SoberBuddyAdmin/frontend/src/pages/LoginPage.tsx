import { FormEvent, useState } from 'react';
import { Navigate } from 'react-router-dom';
import { devAdminOtp, useAuth } from '../context/AuthContext';
import './LoginPage.css';

export default function LoginPage() {
  const { user, admin, otpVerified, loading, devOtpEnabled, login, sendOtp, verifyOtp } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [otp, setOtp] = useState('');
  const [error, setError] = useState('');
  const [otpSent, setOtpSent] = useState(false);
  const [busy, setBusy] = useState(false);

  if (!loading && user && admin && otpVerified) return <Navigate to="/" replace />;

  const onLogin = async (e: FormEvent) => {
    e.preventDefault();
    setBusy(true);
    setError('');
    try {
      await login(email, password);
    } catch (err: any) {
      setError(err.message || 'Login failed');
    } finally {
      setBusy(false);
    }
  };

  const onSendOtp = async () => {
    setBusy(true);
    setError('');
    try {
      await sendOtp();
      setOtpSent(true);
    } catch (err: any) {
      setError(err.message || 'Failed to send OTP');
    } finally {
      setBusy(false);
    }
  };

  const onVerifyOtp = async (e: FormEvent) => {
    e.preventDefault();
    setBusy(true);
    setError('');
    try {
      await verifyOtp(otp);
    } catch (err: any) {
      setError(err.message || 'Invalid OTP');
    } finally {
      setBusy(false);
    }
  };

  const showOtpStep = user && admin && !otpVerified;

  return (
    <div className="login-page">
      <div className="login-card card">
        <h1>SoberBuddy Admin</h1>
        <p className="muted">Driver teal + Rider blue secure console</p>
        <div id="recaptcha-container" />

        {!showOtpStep ? (
          <form onSubmit={onLogin} className="login-form">
            <input className="input" type="email" placeholder="Admin email" value={email} onChange={(e) => setEmail(e.target.value)} required />
            <input className="input" type="password" placeholder="Password" value={password} onChange={(e) => setPassword(e.target.value)} required />
            <button className="btn btn-primary" disabled={busy}>{busy ? 'Signing in...' : 'Sign In'}</button>
          </form>
        ) : (
          <form onSubmit={onVerifyOtp} className="login-form">
            {devOtpEnabled ? (
              <p className="muted">
                Development mode: enter OTP <strong>{devAdminOtp}</strong> (no SMS sent)
              </p>
            ) : (
              <p className="muted">OTP verification required for {admin?.otpPhone || 'registered phone'}</p>
            )}
            {!otpSent && !devOtpEnabled ? (
              <button type="button" className="btn btn-secondary" onClick={onSendOtp} disabled={busy}>Send OTP</button>
            ) : (
              <>
                <input className="input" placeholder="Enter OTP" value={otp} onChange={(e) => setOtp(e.target.value)} required />
                <button className="btn btn-primary" disabled={busy}>Verify OTP</button>
              </>
            )}
          </form>
        )}
        {error && <p className="error">{error}</p>}
      </div>
    </div>
  );
}
