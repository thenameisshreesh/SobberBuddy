export const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY || 'AIzaSyB3DLN7vacRT6RyadXT4n3hA_dVTm1gBV4',
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN || 'soberbuddy-8367f.firebaseapp.com',
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID || 'soberbuddy-8367f',
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET || 'soberbuddy-8367f.firebasestorage.app',
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID || '411558557396',
};
