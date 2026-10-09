import { broadcastLogout } from "./appState.js";

const btn = document.getElementById("logoutBtn");
const link = document.getElementById("logoutLink");

function logout() {
  /*
    REMOVE APENAS O TOKEN.
    NÃO remove:
    - tc_preferences
    - tema
    - fonte
    - contraste
    etc.
  */

  broadcastLogout();
}

if (btn) {
  btn.addEventListener("click", (e) => {
    e.preventDefault();
    logout();
  });
}

if (link) {
  link.addEventListener("click", (e) => {
    e.preventDefault();
    logout();
  });
}