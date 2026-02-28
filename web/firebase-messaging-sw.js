importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

firebase.initializeApp({
    apiKey: "AIzaSyDw6pLDntTwI-K_xpt3GuEx2pFIm6nP1l0",
    authDomain: "scroller-wurp.firebaseapp.com",
    projectId: "scroller-wurp",
    storageBucket: "scroller-wurp.firebasestorage.app",
    messagingSenderId: "418845388234",
    appId: "1:418845388234:web:103c81b1b635273460b333",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
    self.registration.showNotification(payload.notification.title, {
        body: payload.notification.body,
        icon: '/icons/Icon-192.png'
    });
});