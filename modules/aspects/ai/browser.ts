import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

// Runs in a new Ghostty tab in the same window; farsee renders Camofox raw
// VNC through the Kitty graphics protocol and forwards keyboard/mouse.
const viewerCommand = "farsee vnc://netcup:5900";

export default function (pi: ExtensionAPI) {
  pi.registerCommand("browser", {
    description: "Open the shared Camofox browser in a new Ghostty tab (use while OMP is idle)",
    handler: async (_args, ctx) => {
      if (!ctx.isIdle()) {
        ctx.ui.notify("Stop the active turn before taking over the browser.", "warning");
        return;
      }
      const result = await pi.exec("@WL_COPY@", [ viewerCommand ]);
      if (result.code !== 0) {
        ctx.ui.notify("Could not copy the viewer command to the clipboard.", "error");
        return;
      }
      ctx.ui.notify(
        "Viewer command copied. Open a new tab (Ctrl+Shift+T), paste and run it. Quit farsee with Ctrl+Q when done, then ask OMP to resume with a fresh snapshot.",
        "info",
      );
    },
  });
}
