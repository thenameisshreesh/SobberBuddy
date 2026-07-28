import axios from 'axios';
import { getAuth } from 'firebase/auth';

const api = axios.create({ baseURL: '/api' });

api.interceptors.request.use(async (config) => {
  const user = getAuth().currentUser;
  if (user) {
    const token = await user.getIdToken();
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

api.interceptors.response.use(
  (response) => response,
  (error) => {
    const code = error.response?.data?.code;
    if (error.response?.status === 403 && (code === 'OTP_REQUIRED' || code === 'OTP_EXPIRED')) {
      window.dispatchEvent(new CustomEvent('admin-otp-required'));
    }
    return Promise.reject(error);
  },
);

export default api;
