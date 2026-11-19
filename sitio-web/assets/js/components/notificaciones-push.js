/**
 * notificaciones-push.js — Notificaciones push REALES en el navegador (HU-19), con Firebase.
 *
 * Con el permiso del navegador, este navegador queda registrado en la API (POST /api/push/registrar)
 * y cada aviso nuevo llega como notificación del sistema aunque HuellApp esté cerrada.
 * Necesita HTTPS (en tu computadora, http://localhost también sirve) y que la API tenga
 * FIREBASE_CREDENCIALES; si no, no hace nada y la campana sigue funcionando como siempre.
 */
import { get, post } from "../core/api.js";
import { rutaDesdeRaiz } from "../core/utils.js";
import { FIREBASE_CONFIG, VAPID_KEY, FIREBASE_VERSION } from "../core/firebase-config.js";

const CLAVE_TOKEN = "huellapp:push-token";

const soportado = () => "serviceWorker" in navigator && "Notification" in window && "PushManager" in window && window.isSecureContext;

let disponible = null;
/** ¿Se puede usar push aquí? (navegador compatible, página segura y la API configurada) */
export async function pushDisponible() {
  if (disponible !== null) return disponible;
  if (!soportado()) return (disponible = false);
  try { disponible = (await get("/push/estado")).disponible === true; } catch { disponible = false; }
  return disponible;
}

/** ¿Este navegador ya recibe notificaciones push? (entonces la campana no repite el aviso) */
export const pushActivo = () => soportado() && Notification.permission === "granted" && Boolean(leerToken());

function leerToken() { try { return localStorage.getItem(CLAVE_TOKEN); } catch { return null; } }
function guardarToken(t) { try { t ? localStorage.setItem(CLAVE_TOKEN, t) : localStorage.removeItem(CLAVE_TOKEN); } catch { /* sin acceso */ } }

function cargarScript(src) {
  return new Promise((resolver, rechazar) => {
    if (document.querySelector(`script[src="${src}"]`)) { resolver(); return; }
    const s = document.createElement("script");
    s.src = src;
    s.onload = resolver;
    s.onerror = () => rechazar(new Error("No se pudo cargar Firebase (¿sin internet?)."));
    document.head.append(s);
  });
}

async function mensajeria() {
  const base = `https://www.gstatic.com/firebasejs/${FIREBASE_VERSION}`;
  await cargarScript(`${base}/firebase-app-compat.js`);
  await cargarScript(`${base}/firebase-messaging-compat.js`);
  if (!window.firebase.apps.length) window.firebase.initializeApp(FIREBASE_CONFIG);
  return window.firebase.messaging();
}

/** Pide el token de este navegador a Firebase y lo registra en la API. */
async function registrar() {
  const registro = await navigator.serviceWorker.register(rutaDesdeRaiz("firebase-messaging-sw.js"));
  const token = await (await mensajeria()).getToken({ vapidKey: VAPID_KEY, serviceWorkerRegistration: registro });
  if (!token) throw new Error("Firebase no entregó el identificador de este navegador.");
  await post("/push/registrar", { token, plataforma: "web" });
  guardarToken(token);
  return token;
}

/**
 * Al abrir cualquier página con sesión: si ya dio permiso, renueva el registro en silencio
 * (el token puede cambiar o venir de otra cuenta que usó este navegador).
 */
export async function prepararPush() {
  if (!(await pushDisponible()) || Notification.permission !== "granted") return;
  try { await registrar(); } catch (e) { console.warn("Notificaciones push:", e.message); }
}

/** Botón «Activar notificaciones»: pide el permiso y registra. Devuelve { ok, mensaje }. */
export async function activarPush() {
  if (!(await pushDisponible())) return { ok: false, mensaje: "Este navegador o esta dirección no permite notificaciones push." };
  const permiso = await Notification.requestPermission();
  if (permiso !== "granted") return { ok: false, mensaje: "No diste permiso. Puedes activarlo en el candado de la barra de direcciones." };
  try {
    await registrar();
    return { ok: true, mensaje: "¡Listo! Te avisaremos aunque HuellApp esté cerrada." };
  } catch (e) {
    return { ok: false, mensaje: e.message || "No se pudieron activar las notificaciones." };
  }
}

/** Al cerrar sesión: este navegador deja de recibir los avisos de la cuenta. */
export async function quitarPush() {
  const token = leerToken();
  if (!token) return;
  guardarToken(null);
  try { await post("/push/quitar", { token }); } catch { /* sin conexión: la API lo borra cuando FCM diga que ya no sirve */ }
}
