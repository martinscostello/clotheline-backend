importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js");

const firebaseConfig = {
    apiKey: "AIzaSyB_mF4xxgOSzrSoMXpIpr48ZIFZKN7xpSc",
    authDomain: "clotheline.firebaseapp.com",
    projectId: "clotheline",
    storageBucket: "clotheline.firebasestorage.app",
    messagingSenderId: "641268154673",
    appId: "1:641268154673:web:28a5bd63af3cd58528f010"
};

firebase.initializeApp(firebaseConfig);
const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
    console.log('[firebase-messaging-sw.js] Received background message ', payload);
    const notificationTitle = payload.notification?.title || 'New Web Notification';
    const notificationOptions = {
        body: payload.notification?.body,
        icon: '/icons/Icon-192.png'
    };

    self.registration.showNotification(notificationTitle, notificationOptions);
});
