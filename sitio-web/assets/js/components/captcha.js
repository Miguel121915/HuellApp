/**
 * captcha.js — «No soy un robot» con Cloudflare Turnstile (registro y login tras varios fallos).
 * Solo aparece si la API tiene TURNSTILE_SITE_KEY (ver api/src/Captcha.php). Sin clave no hace nada.
 */
const SCRIPT = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit";
let cargando = null;

function cargarTurnstile() {
  if (window.turnstile) return Promise.resolve(true);
  cargando ??= new Promise((resolver) => {
    const s = document.createElement("script");
    s.src = SCRIPT;
    s.async = true;
    s.onload = () => resolver(Boolean(window.turnstile));
    s.onerror = () => resolver(false);
    document.head.append(s);
  });
  return cargando;
}

/**
 * Dibuja el CAPTCHA dentro de `contenedor` (que se hace visible).
 * @returns {Promise<{token: () => string, reiniciar: () => void} | null>} null si no se pudo cargar
 */
export async function montarCaptcha(contenedor, claveSitio) {
  if (!claveSitio) return null;
  contenedor.hidden = false;
  if (!(await cargarTurnstile())) {
    contenedor.textContent = "No se pudo cargar la verificación «no soy un robot». Revisa tu conexión y recarga la página.";
    return null;
  }
  let token = "";
  const id = window.turnstile.render(contenedor, {
    sitekey: claveSitio,
    language: "es",
    callback: (t) => { token = t; },
    "expired-callback": () => { token = ""; },
    "error-callback": () => { token = ""; },
  });
  return {
    token: () => token,
    // Cada token sirve una sola vez: después de enviarlo se pide uno nuevo
    reiniciar: () => { token = ""; window.turnstile.reset(id); },
  };
}
