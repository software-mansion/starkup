const INSTALL_COMMAND = "curl --proto '=https' --tlsv1.2 -sSf https://sh.starkup.sh | sh";

let copyTimeout = null;

async function copyToClipboard(button) {
  try {
    await navigator.clipboard.writeText(INSTALL_COMMAND);

    if (copyTimeout) {
      clearTimeout(copyTimeout);
    }

    button.classList.remove("copied");
    void button.offsetWidth;
    button.classList.add("copied");

    copyTimeout = setTimeout(() => {
      button.classList.remove("copied");
      copyTimeout = null;
    }, 2000);
  } catch (err) {
    console.error("Failed to copy to clipboard:", err);
  }
}

(function() {
  document.querySelectorAll(".copy-button").forEach((btn) => {
    btn.addEventListener("click", () => copyToClipboard(btn));
  });
})();