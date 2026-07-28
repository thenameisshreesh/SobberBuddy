import { createContext, useContext, useEffect, useMemo, useState, ReactNode } from 'react';
import {
  User,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut as firebaseSignOut,
  RecaptchaVerifier,
  signInWithPhoneNumber,
} from 'firebase/auth';
import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { firebaseConfig } from '../firebase';
import api from '../api/client';

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);

/** Fixed dev OTP — no SMS required when set (matches backend DEV_ADMIN_OTP). */
export const devAdminOtp = import.meta.env.VITE_DEV_ADMIN_OTP || '';

type AdminProfile = {
  id: string;
  email?: string;
  name?: string;
  otpPhone?: string;
  role?: string;
};

type AuthContextValue = {
  user: User | null;
  admin: AdminProfile | null;
  otpVerified: boolean;
  loading: boolean;
  devOtpEnabled: boolean;
  login: (email: string, password: string) => Promise<void>;
  verifyOtp: (code: string) => Promise<void>;
  sendOtp: () => Promise<void>;
  logout: () => Promise<void>;
};

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [admin, setAdmin] = useState<AdminProfile | null>(null);
  const [otpVerified, setOtpVerified] = useState(false);
  const [loading, setLoading] = useState(true);
  const [confirmation, setConfirmation] = useState<any>(null);
  const devOtpEnabled = Boolean(devAdminOtp);

  const completeAdminSession = async (data: { admin: AdminProfile; otpRequired: boolean }) => {
    setAdmin(data.admin);
    if (data.otpRequired && devOtpEnabled && devAdminOtp) {
      try {
        await api.post('/auth/verify-otp', { code: devAdminOtp });
        setOtpVerified(true);
        return;
      } catch {
        setOtpVerified(false);
        return;
      }
    }
    setOtpVerified(!data.otpRequired);
  };

  useEffect(() => {
    const onOtpRequired = () => setOtpVerified(false);
    window.addEventListener('admin-otp-required', onOtpRequired);
    return () => window.removeEventListener('admin-otp-required', onOtpRequired);
  }, []);

  useEffect(() => {
    return onAuthStateChanged(auth, async (nextUser) => {
      setUser(nextUser);
      if (!nextUser) {
        setAdmin(null);
        setOtpVerified(false);
        setLoading(false);
        return;
      }
      try {
        const { data } = await api.post('/auth/check-admin');
        await completeAdminSession(data);
      } catch {
        setAdmin(null);
        setOtpVerified(false);
      } finally {
        setLoading(false);
      }
    });
  }, []);

  const login = async (email: string, password: string) => {
    await signInWithEmailAndPassword(auth, email, password);
    const { data } = await api.post('/auth/check-admin');
    if (!data.isAdmin) throw new Error('Not authorized as admin');
    await completeAdminSession(data);
  };

  const sendOtp = async () => {
    if (devOtpEnabled) {
      setConfirmation({ dev: true });
      return;
    }
    if (!admin?.otpPhone) throw new Error('Admin phone not configured');
    const verifier = new RecaptchaVerifier(auth, 'recaptcha-container', { size: 'invisible' });
    const result = await signInWithPhoneNumber(auth, admin.otpPhone, verifier);
    setConfirmation(result);
  };

  const verifyOtp = async (code: string) => {
    if (devOtpEnabled) {
      await api.post('/auth/verify-otp', { code });
      setOtpVerified(true);
      return;
    }
    if (!confirmation) throw new Error('Request OTP first');
    await confirmation.confirm(code);
    await api.post('/auth/verify-otp');
    setOtpVerified(true);
  };

  const logout = async () => {
    try {
      await api.post('/auth/logout');
    } catch {
      /* ignore */
    }
    await firebaseSignOut(auth);
    setAdmin(null);
    setOtpVerified(false);
    setConfirmation(null);
  };

  const value = useMemo(
    () => ({
      user,
      admin,
      otpVerified,
      loading,
      devOtpEnabled,
      login,
      verifyOtp,
      sendOtp,
      logout,
    }),
    [user, admin, otpVerified, loading, devOtpEnabled],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
}
