/** @type {import('tailwindcss').Config} */
module.exports = {
  // Scans markup AND the class names inside the JS template strings in Default.aspx.
  content: ['./Default.aspx'],
  darkMode: ['selector', '[data-theme="dark"]'],
  theme: {
    extend: {},
  },
  plugins: [],
};
