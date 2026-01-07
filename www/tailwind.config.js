/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./public/**/*.html"],
  theme: {
    extend: {
      colors: {
        primary: "var(--c-primary)",
        secondary: "var(--c-secondary)",
        accent: "var(--c-accent)",
        muted: "var(--c-muted)",
        "page-bg": "var(--c-page-bg)",
        "card-bg": "var(--c-card-bg)",
        "snippet-bg": "var(--c-snippet-bg)",
        "snippet-text": "var(--c-snippet-text)",
        border: "var(--c-border)",
      },
      boxShadow: {
        card: "var(--shadow-card)",
      },
    },
  },
  plugins: [],
};
