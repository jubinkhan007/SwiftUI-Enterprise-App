import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";

// The SPA calls the backend through a same-origin `/api` prefix, which Vite proxies
// to the Vapor server in dev. Same-origin keeps the HttpOnly `SameSite=Strict`
// session cookies first-party. In production, put a reverse proxy in front that
// serves the built assets and forwards `/api` to the backend (see ADMIN_PANEL_SETUP.md).
const BACKEND = process.env.ADMIN_API_PROXY ?? "http://127.0.0.1:8080";

export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    port: 5173,
    proxy: {
      "/api": {
        target: BACKEND,
        changeOrigin: true,
      },
    },
  },
});
