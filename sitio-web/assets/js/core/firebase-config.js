/**
 * firebase-config.js — Datos PÚBLICOS del proyecto de Firebase de HuellApp (proyecto huellapp-b42ba).
 * Viajan dentro de la página web en cualquier sitio que use Firebase: no son secretos.
 * Lo secreto (la cuenta de servicio con la que la API envía las notificaciones) vive solo en el
 * servidor, fuera del proyecto (FIREBASE_CREDENCIALES en api/.env).
 *
 * Si cambia el proyecto de Firebase, actualiza también firebase-messaging-sw.js (raíz del sitio).
 */
export const FIREBASE_CONFIG = {
  apiKey: "AIzaSyDTtLQdLjarek5xhCZE0QKwLuDA9VNutKo",
  authDomain: "huellapp-b42ba.firebaseapp.com",
  projectId: "huellapp-b42ba",
  storageBucket: "huellapp-b42ba.firebasestorage.app",
  messagingSenderId: "1012369050353",
  appId: "1:1012369050353:web:0b2c25c0c27a6a045ef750",
};

/** Clave pública VAPID (Cloud Messaging → Certificados push web). */
export const VAPID_KEY = "BDGV0kF_ONLwf6co-vHZSc8UoyckDyKvDSQWlvDCefU37jgR95iiixnvjsrnp8uLZsu6yyjr4AroziVSOm4pLBk";

/** Versión de las librerías de Firebase (se cargan desde gstatic.com, el sitio oficial de Google). */
export const FIREBASE_VERSION = "10.14.1";
