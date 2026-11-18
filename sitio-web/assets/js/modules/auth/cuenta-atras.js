/**
 * cuenta-atras.js — Botón «Reenviar código» que se desactiva y cuenta los segundos que faltan.
 * Lo usan «Confirma tu correo» y «Recuperar contraseña».
 */
export function iniciarCuentaAtras(boton, texto) {
  let reloj = null;
  return {
    /** Desactiva el botón `segundos` segundos (0 = lo deja usable de inmediato). */
    iniciar(segundos) {
      clearInterval(reloj);
      let quedan = Math.max(0, Math.round(segundos));
      const pintar = () => {
        boton.disabled = quedan > 0;
        boton.textContent = quedan > 0 ? `${texto} (${quedan} s)` : texto;
      };
      pintar();
      if (quedan === 0) return;
      reloj = setInterval(() => {
        quedan -= 1;
        pintar();
        if (quedan <= 0) clearInterval(reloj);
      }, 1000);
    },
  };
}
