import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

const url = "http://netcup:6080/vnc.html";

export default function (pi: ExtensionAPI) {
  pi.registerCommand("browser-view", {
    description: "Open the shared Camofox browser (use while OMP is idle)",
    handler: async (_args, ctx) => {
      if (!ctx.isIdle()) {
        ctx.ui.notify("Stop the active turn before taking over the browser.", "warning");
        return;
      }
      const result = await pi.exec("@XDG_OPEN@", [url]);
      if (result.code !== 0) {
        ctx.ui.notify(`Could not open the viewer. Open ${url} manually.`, "error");
        return;
      }
      ctx.ui.notify("Camofox viewer opened. Finish your manual actions, then ask OMP to resume with a fresh snapshot.", "info");
    },
  });
}
