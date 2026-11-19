/**
 * firebase-messaging-sw.js — Service worker de las notificaciones push (HU-19).
 * Recibe los avisos aunque la página de HuellApp esté cerrada y los muestra como notificación del
 * sistema; al tocarla abre la página del aviso. Debe vivir en la RAÍZ del sitio para cubrir todas
 * las páginas. Los datos de Firebase son públicos (ver assets/js/core/firebase-config.js).
 */
importScripts("https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyDTtLQdLjarek5xhCZE0QKwLuDA9VNutKo",
  authDomain: "huellapp-b42ba.firebaseapp.com",
  projectId: "huellapp-b42ba",
  storageBucket: "huellapp-b42ba.firebasestorage.app",
  messagingSenderId: "1012369050353",
  appId: "1:1012369050353:web:0b2c25c0c27a6a045ef750",
});

// Con la página cerrada o en segundo plano, Firebase muestra solo la notificación (título, texto y
// el enlace de fcm_options que manda la API). Inicializarlo aquí es lo que lo activa.
firebase.messaging();
