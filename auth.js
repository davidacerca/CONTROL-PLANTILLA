
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const config = window.ACERCA_SUPABASE_CONFIG;

const form = document.getElementById("loginForm");
const emailInput = document.getElementById("loginEmail");
const passwordInput = document.getElementById("loginPassword");
const loginButton = document.getElementById("loginButton");
const message = document.getElementById("authMessage");
const logoutButton = document.getElementById("logoutButton");

function showMessage(text, type = "error") {
  message.textContent = text;
  message.className = `auth-message ${type}`;
}

function clearMessage() {
  message.textContent = "";
  message.className = "auth-message";
}

function showLogin() {
  document.body.classList.remove("acerca-authenticated");
  if (passwordInput) passwordInput.value = "";
}

function showApp(user) {
  document.body.classList.add("acerca-authenticated");

  const email = user?.email || "Administración";

  document.getElementById("currentAdminEmail").textContent = email;
  document.getElementById("sidebarAdminEmail").textContent = email;

  clearMessage();
}

const validConfig =
  config &&
  typeof config.supabaseUrl === "string" &&
  typeof config.supabasePublishableKey === "string" &&
  config.supabasePublishableKey.startsWith("sb_publishable_");

if (!form || !loginButton || !logoutButton) {
  console.error("No se encuentran los elementos del acceso de Acerca.");
} else if (!validConfig) {
  showLogin();
  showMessage(
    "Falta configurar la conexión con Supabase.",
    "info"
  );
  loginButton.disabled = true;
} else {
  const supabase = createClient(
    config.supabaseUrl,
    config.supabasePublishableKey
  );

  async function authorizeSession(session) {
    if (!session?.user) {
      showLogin();
      return;
    }

    const { data, error } = await supabase.rpc("is_acerca_admin");

    if (error || data !== true) {
      await supabase.auth.signOut();
      showLogin();

      showMessage(
        "Esta cuenta no está autorizada para acceder a Acerca."
      );

      return;
    }

    showApp(session.user);
  }

  form.addEventListener("submit", async (event) => {
    event.preventDefault();

    clearMessage();

    loginButton.disabled = true;
    loginButton.textContent = "Comprobando acceso...";

    try {
      const { data, error } = await supabase.auth.signInWithPassword({
        email: emailInput.value.trim(),
        password: passwordInput.value
      });

      if (error) {
        showMessage(
          "No se ha podido iniciar sesión. Comprueba tus credenciales."
        );
        return;
      }

      await authorizeSession(data.session);

    } catch (error) {
      console.error(error);

      showMessage(
        "No se ha podido conectar con Supabase."
      );

    } finally {
      loginButton.disabled = false;
      loginButton.textContent = "Iniciar sesión";
    }
  });

  logoutButton.addEventListener("click", async () => {
    logoutButton.disabled = true;

    const { error } = await supabase.auth.signOut();

    logoutButton.disabled = false;

    if (error) {
      showMessage("No se ha podido cerrar la sesión.");
    } else {
      showLogin();
    }
  });

  supabase.auth.onAuthStateChange((event) => {
    if (event === "SIGNED_OUT") {
      showLogin();
    }
  });

  supabase.auth.getSession().then(({ data, error }) => {
    if (error) {
      showLogin();
      showMessage("No se ha podido comprobar la sesión.");
      return;
    }

    authorizeSession(data.session);
  });
}
