/** inicio-app.js — index.html: decide a dónde ir según la sesión. */
import { obtenerSesion } from "../../core/auth.js";
import { destinoDeSesion, RUTA_LOGIN } from "../../core/router-guard.js";
import { irA } from "../../core/utils.js";

const sesion = obtenerSesion();
irA(sesion ? destinoDeSesion(sesion) : RUTA_LOGIN);
