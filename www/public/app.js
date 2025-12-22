const INSTALL_COMMAND = "curl --proto '=https' --tlsv1.2 -sSf https://sh.starkup.sh | sh";

// Attempt to recognize Unix and Windows platforms, return "unknown" for others.
function detectPlatform() {
  const userAgent = navigator.userAgent || "";
  const platform = navigator.platform || "";
  const userAgentHints = navigator.userAgentData;

  if (userAgentHints?.platform) {
    const platform_hint = userAgentHints.platform;
    const isMobile = !!userAgentHints.mobile;
    if (isMobile) return "unknown";
    if (platform_hint === "Windows") return "windows";
    if (platform_hint === "macOS" || platform_hint === "Linux" || platform_hint === "Chrome OS") return "unix";
  }

  // Fallbacks if User-Agent Client Hints are not supported
  const isIPadOS = (platform === "MacIntel" || userAgent.includes("Macintosh")) && (navigator.maxTouchPoints || 0) > 1;
  if (isIPadOS) return "unknown";

  if (/\bAndroid\b/i.test(userAgent)) return "unknown";
  if (/\biPhone|iPad|iPod\b/i.test(userAgent)) return "unknown";

  if (/\bWindows\b/i.test(userAgent) || platform.startsWith("Win")) return "windows";
  if (platform.includes("Mac") || /\bMac OS X\b/i.test(userAgent)) return "unix";
  if (platform.includes("Linux") || /\bLinux\b/i.test(userAgent)) return "unix";

  return "unknown";
}

function adjustPlatformHints() {
  const platform = detectPlatform();

  if (platform === "windows") {
    document.getElementById("warning-windows")?.classList.remove("hidden");
  } else if (platform === "unknown") {
    document.getElementById("warning-unknown")?.classList.remove("hidden");
    document.getElementById("instructions-default")?.classList.add("hidden");
    document.getElementById("instructions-unknown")?.classList.remove("hidden");
  }
}

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
  adjustPlatformHints();

  document.querySelectorAll(".copy-button").forEach((btn) => {
    btn.addEventListener("click", () => copyToClipboard(btn));
  });
})();
