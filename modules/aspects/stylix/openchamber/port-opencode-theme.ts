#!/usr/bin/env bun

/*
 * Generate OpenChamber themes from Stylix's OpenCode theme output.
 *
 * Usage:
 *   bun port-opencode-theme.ts --out-dir ./themes stylix-opencode-theme.json
 *   bun port-opencode-theme.ts --stdout stylix-opencode-theme.json
 */
// @ts-nocheck
import fs from "node:fs/promises";
import path from "node:path";

type Mode = "dark" | "light";
type ModeColor = string | { dark: string; light: string };
type OpenCodeThemeInput = {
  theme?: Record<string, ModeColor>;
} & Record<string, ModeColor | Record<string, ModeColor> | undefined>;
type OpenCodeTheme = Record<string, string>;

type ParsedArgs = {
  outDir: string;
  stdout: boolean;
  inputPath?: string;
};

const DEFAULT_OUT_DIR = path.resolve("openchamber-themes");

const DEFAULT_CONFIG = {
  fonts: {
    sans: '"JetBrainsMono Nerd Font", monospace',
    mono: '"JetBrainsMono Nerd Font", monospace',
    heading: '"JetBrainsMono Nerd Font", monospace',
  },
  radius: {
    none: "0",
    sm: "0.125rem",
    md: "0.375rem",
    lg: "0.5rem",
    xl: "0.75rem",
    full: "9999px",
  },
  spacing: {
    xs: "0.25rem",
    sm: "0.5rem",
    md: "0.75rem",
    lg: "1rem",
    xl: "1.5rem",
  },
  transitions: {
    fast: "150ms ease",
    normal: "250ms ease",
    slow: "350ms ease",
  },
};

function usage(): void {
  console.error(
    [
      "Usage: bun port-opencode-theme.ts [options] <stylix-opencode-theme.json>",
      "",
      "Options:",
      "  --out-dir <path>  Output directory (default: ./openchamber-themes)",
      "  --stdout          Print generated JSON instead of writing files",
    ].join("\n"),
  );
}

function parseArgs(argv: string[]): ParsedArgs {
  const args: ParsedArgs = {
    outDir: DEFAULT_OUT_DIR,
    stdout: false,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (!arg) continue;

    if (arg === "--out-dir") {
      const value = argv[index + 1];
      if (!value) throw new Error("Missing value for --out-dir");
      args.outDir = path.resolve(value);
      index += 1;
      continue;
    }

    if (arg === "--stdout") {
      args.stdout = true;
      continue;
    }

    if (arg.startsWith("--")) {
      throw new Error(`Unknown option: ${arg}`);
    }

    if (args.inputPath) {
      throw new Error(`Unexpected extra input: ${arg}`);
    }
    args.inputPath = path.resolve(arg);
  }

  return args;
}

function normalizeInput(raw: OpenCodeThemeInput): Record<string, ModeColor> {
  if (raw.theme && typeof raw.theme === "object") {
    return raw.theme;
  }
  return raw as Record<string, ModeColor>;
}

function selectMode(
  theme: Record<string, ModeColor>,
  mode: Mode,
): OpenCodeTheme {
  const selected: OpenCodeTheme = {};

  for (const [key, value] of Object.entries(theme)) {
    if (typeof value === "string") {
      selected[key] = value;
      continue;
    }

    if (value && typeof value === "object") {
      const color = value[mode];
      if (typeof color === "string") selected[key] = color;
    }
  }

  return selected;
}

function token(theme: OpenCodeTheme, key: string, fallback: string): string {
  return theme[key] ?? fallback;
}

function formatOpacity(opacity: number): string {
  return opacity.toFixed(3).replace(/0+$/u, "").replace(/\.$/u, "");
}

function withAlpha(color: string, opacity: number): string {
  const value = color.trim();
  const alpha = Math.max(0, Math.min(1, opacity));
  const hex = value.replace(/^#/u, "");

  if (/^[0-9a-f]{3}$/iu.test(hex)) {
    const expanded = hex
      .split("")
      .map((part) => `${part}${part}`)
      .join("");
    const alphaHex = Math.round(alpha * 255)
      .toString(16)
      .padStart(2, "0");
    return `#${expanded}${alphaHex}`;
  }

  if (/^[0-9a-f]{6}$/iu.test(hex)) {
    const alphaHex = Math.round(alpha * 255)
      .toString(16)
      .padStart(2, "0");
    return `#${hex}${alphaHex}`;
  }

  const rgb = value.match(
    /^rgba?\(\s*([0-9]{1,3})\s*,\s*([0-9]{1,3})\s*,\s*([0-9]{1,3})(?:\s*,\s*[0-9.]+)?\s*\)$/iu,
  );
  if (rgb) {
    return `rgba(${rgb[1]}, ${rgb[2]}, ${rgb[3]}, ${formatOpacity(alpha)})`;
  }

  return color;
}

function parseRgb(color: string): [number, number, number] | null {
  const value = color.trim();
  const hex = value.replace(/^#/u, "");

  if (/^[0-9a-f]{3}$/iu.test(hex)) {
    return hex.split("").map((part) => parseInt(`${part}${part}`, 16)) as [
      number,
      number,
      number,
    ];
  }

  if (/^[0-9a-f]{6}$/iu.test(hex) || /^[0-9a-f]{8}$/iu.test(hex)) {
    const normalized = hex.slice(0, 6);
    return [
      parseInt(normalized.slice(0, 2), 16),
      parseInt(normalized.slice(2, 4), 16),
      parseInt(normalized.slice(4, 6), 16),
    ];
  }

  const rgb = value.match(
    /^rgba?\(\s*([0-9]{1,3})\s*,\s*([0-9]{1,3})\s*,\s*([0-9]{1,3})(?:\s*,\s*[0-9.]+)?\s*\)$/iu,
  );
  if (!rgb) return null;
  return [Number(rgb[1]), Number(rgb[2]), Number(rgb[3])];
}

function relativeLuminance(color: string): number | null {
  const rgb = parseRgb(color);
  if (!rgb) return null;

  const [red, green, blue] = rgb.map((channel) => {
    const normalized = channel / 255;
    if (normalized <= 0.03928) return normalized / 12.92;
    return ((normalized + 0.055) / 1.055) ** 2.4;
  });

  return 0.2126 * red + 0.7152 * green + 0.0722 * blue;
}

function contrastRatio(foreground: string, background: string): number | null {
  const fg = relativeLuminance(foreground);
  const bg = relativeLuminance(background);
  if (fg === null || bg === null) return null;

  const light = Math.max(fg, bg);
  const dark = Math.min(fg, bg);
  return (light + 0.05) / (dark + 0.05);
}

function accessibleForeground(background: string, preferred?: string): string {
  if (preferred) {
    const ratio = contrastRatio(preferred, background);
    if (ratio !== null && ratio >= 4.5) return preferred;
  }

  const black = "#151313";
  const white = "#ffffff";
  const blackRatio = contrastRatio(black, background) ?? 0;
  const whiteRatio = contrastRatio(white, background) ?? 0;
  return blackRatio >= whiteRatio ? black : white;
}

function buildTheme(theme: OpenCodeTheme, mode: Mode) {
  const isDark = mode === "dark";
  const background = token(theme, "background", isDark ? "#151313" : "#FFFCF0");
  const foreground = token(theme, "text", isDark ? "#CECDC3" : "#100F0F");
  const mutedText = token(theme, "textMuted", isDark ? "#878580" : "#6F6E69");
  const panel = token(theme, "backgroundPanel", background);
  const element = token(theme, "backgroundElement", panel);
  const border = token(
    theme,
    "border",
    withAlpha(foreground, isDark ? 0.2 : 0.16),
  );
  const borderActive = token(
    theme,
    "borderActive",
    token(theme, "primary", border),
  );
  const primary = token(theme, "primary", borderActive);
  const secondary = token(theme, "secondary", token(theme, "accent", primary));
  const success = token(theme, "success", "#66800B");
  const warning = token(theme, "warning", "#DA702C");
  const error = token(theme, "error", "#AF3029");
  const info = token(theme, "info", secondary);
  const hover = withAlpha(foreground, isDark ? 0.09 : 0.055);
  const active = withAlpha(foreground, isDark ? 0.12 : 0.085);
  const primaryForeground = accessibleForeground(primary);
  const successForeground = accessibleForeground(success);
  const warningForeground = accessibleForeground(warning);
  const errorForeground = accessibleForeground(error);
  const infoForeground = accessibleForeground(info);
  const diffAdded = token(theme, "diffAdded", success);
  const diffRemoved = token(theme, "diffRemoved", error);
  const diffModified = token(theme, "diffHunkHeader", warning);
  const diffAddedBg = token(
    theme,
    "diffAddedBg",
    withAlpha(success, isDark ? 0.16 : 0.12),
  );
  const diffRemovedBg = token(
    theme,
    "diffRemovedBg",
    withAlpha(error, isDark ? 0.16 : 0.12),
  );
  const diffContextBg = token(
    theme,
    "diffContextBg",
    withAlpha(info, isDark ? 0.1 : 0.08),
  );

  return {
    metadata: {
      id: `stylix-${mode}`,
      name: "Stylix",
      description: `Generated from Stylix's OpenCode theme (${mode} variant)`,
      author: "Stylix",
      version: "1.0.0",
      variant: mode,
      tags: [mode, "stylix", "opencode", "generated"],
    },
    colors: {
      primary: {
        base: primary,
        hover: primary,
        active: borderActive,
        foreground: primaryForeground,
        muted: withAlpha(primary, 0.5),
        emphasis: primary,
      },
      surface: {
        background,
        foreground,
        muted: panel,
        mutedForeground: mutedText,
        elevated: element,
        elevatedForeground: foreground,
        overlay: withAlpha(background, isDark ? 0.84 : 0.24),
        subtle: panel,
      },
      interactive: {
        border,
        borderHover: token(theme, "borderSubtle", border),
        borderFocus: borderActive,
        selection: active,
        selectionForeground: foreground,
        focus: borderActive,
        focusRing: withAlpha(borderActive, isDark ? 0.38 : 0.28),
        cursor: foreground,
        hover,
        active,
      },
      status: {
        error,
        errorForeground,
        errorBackground: withAlpha(error, isDark ? 0.16 : 0.12),
        errorBorder: withAlpha(error, isDark ? 0.45 : 0.35),
        warning,
        warningForeground,
        warningBackground: withAlpha(warning, isDark ? 0.16 : 0.12),
        warningBorder: withAlpha(warning, isDark ? 0.45 : 0.35),
        success,
        successForeground,
        successBackground: withAlpha(success, isDark ? 0.16 : 0.12),
        successBorder: withAlpha(success, isDark ? 0.45 : 0.35),
        info,
        infoForeground,
        infoBackground: withAlpha(info, isDark ? 0.16 : 0.12),
        infoBorder: withAlpha(info, isDark ? 0.45 : 0.35),
      },
      pr: {
        open: success,
        draft: mutedText,
        blocked: warning,
        merged: secondary,
        closed: error,
      },
      syntax: {
        base: {
          background: element,
          foreground,
          comment: token(theme, "syntaxComment", mutedText),
          keyword: token(theme, "syntaxKeyword", secondary),
          string: token(theme, "syntaxString", success),
          number: token(theme, "syntaxNumber", info),
          function: token(theme, "syntaxFunction", primary),
          variable: token(theme, "syntaxVariable", foreground),
          type: token(theme, "syntaxType", warning),
          operator: token(theme, "syntaxOperator", foreground),
        },
        tokens: {
          commentDoc: token(theme, "syntaxComment", mutedText),
          stringEscape: token(theme, "syntaxString", success),
          keywordImport: token(theme, "syntaxKeyword", secondary),
          storageModifier: token(theme, "syntaxKeyword", secondary),
          functionCall: token(theme, "syntaxFunction", primary),
          method: token(theme, "syntaxFunction", primary),
          variableProperty: token(theme, "syntaxFunction", primary),
          variableOther: token(theme, "syntaxVariable", foreground),
          variableGlobal: token(theme, "syntaxNumber", info),
          variableLocal: token(theme, "syntaxPunctuation", mutedText),
          parameter: token(theme, "syntaxVariable", foreground),
          constant: token(theme, "syntaxNumber", info),
          class: token(theme, "syntaxType", warning),
          className: token(theme, "syntaxType", warning),
          interface: token(theme, "syntaxType", warning),
          struct: token(theme, "syntaxType", warning),
          enum: token(theme, "syntaxType", warning),
          typeParameter: token(theme, "syntaxType", warning),
          namespace: token(theme, "syntaxType", warning),
          module: token(theme, "syntaxKeyword", secondary),
          tag: token(theme, "syntaxKeyword", secondary),
          jsxTag: token(theme, "syntaxKeyword", secondary),
          tagAttribute: token(theme, "syntaxFunction", primary),
          tagAttributeValue: token(theme, "syntaxString", success),
          boolean: token(theme, "syntaxNumber", info),
          decorator: token(theme, "syntaxKeyword", secondary),
          label: token(theme, "syntaxFunction", primary),
          punctuation: token(theme, "syntaxPunctuation", mutedText),
          macro: token(theme, "syntaxKeyword", secondary),
          preprocessor: token(theme, "syntaxKeyword", secondary),
          regex: token(theme, "syntaxString", success),
          url: token(theme, "markdownLink", primary),
          key: token(theme, "syntaxFunction", primary),
          exception: error,
        },
        highlights: {
          diffAdded,
          diffAddedBackground: diffAddedBg,
          diffRemoved,
          diffRemovedBackground: diffRemovedBg,
          diffModified,
          diffModifiedBackground: diffContextBg,
          lineNumber: token(theme, "diffLineNumber", mutedText),
          lineNumberActive: foreground,
        },
      },
      header: {
        background,
        foreground,
        border,
        icon: mutedText,
        hover: element,
      },
      sidebar: {
        background: panel,
        foreground: mutedText,
        border,
        icon: mutedText,
        hover: element,
        active,
        accent: primary,
        accentForeground: primaryForeground,
      },
      chat: {
        background,
        userMessage: foreground,
        userMessageBackground: element,
        assistantMessage: foreground,
        assistantMessageBackground: background,
        timestamp: mutedText,
        divider: border,
        typing: mutedText,
      },
      markdown: {
        heading1: token(theme, "markdownHeading", primary),
        heading2: token(theme, "markdownHeading", primary),
        heading3: foreground,
        heading4: foreground,
        link: token(theme, "markdownLink", primary),
        linkHover: token(theme, "markdownLinkText", primary),
        inlineCode: token(theme, "markdownCode", success),
        inlineCodeBackground: token(theme, "markdownCodeBlock", element),
        blockquote: token(theme, "markdownBlockQuote", mutedText),
        blockquoteBorder: border,
        listMarker: token(theme, "markdownListItem", primary),
        bold: token(theme, "markdownStrong", foreground),
        italic: token(theme, "markdownEmph", mutedText),
        strikethrough: mutedText,
        hr: token(theme, "markdownHorizontalRule", border),
      },
      tools: {
        background: element,
        border,
        headerHover: hover,
        icon: mutedText,
        title: foreground,
        description: mutedText,
        edit: {
          added: diffAdded,
          addedBackground: diffAddedBg,
          removed: diffRemoved,
          removedBackground: diffRemovedBg,
          modified: diffModified,
          modifiedBackground: diffContextBg,
          lineNumber: mutedText,
        },
        bash: { background: element, foreground, info, warning, error },
        lsp: { background: element, foreground, info, warning, error },
      },
      forms: {
        inputBackground: element,
        inputForeground: foreground,
        inputBorder: border,
        inputBorderHover: token(theme, "borderSubtle", border),
        inputBorderFocus: borderActive,
        inputPlaceholder: mutedText,
        inputDisabled: panel,
        inputSelection: active,
        label: mutedText,
        helperText: mutedText,
      },
      buttons: {
        primary: {
          bg: primary,
          fg: primaryForeground,
          border: primary,
          hover: primary,
          active: borderActive,
          disabled: panel,
        },
        secondary: {
          bg: element,
          fg: foreground,
          border,
          hover,
          active,
          disabled: panel,
        },
        ghost: {
          bg: "#00000000",
          fg: foreground,
          border: "#00000000",
          hover,
          active,
          disabled: mutedText,
        },
        destructive: {
          bg: error,
          fg: errorForeground,
          border: error,
          hover: withAlpha(error, 0.72),
          active: error,
          disabled: panel,
        },
      },
      modal: {
        background: element,
        foreground,
        border,
        overlay: withAlpha(background, isDark ? 0.84 : 0.24),
      },
      popover: {
        background: element,
        foreground,
        border,
        shadow: isDark
          ? "0 18px 48px rgba(0, 0, 0, 0.45)"
          : "0 18px 48px rgba(15, 15, 15, 0.16)",
      },
      commandPalette: {
        background: element,
        foreground,
        border,
        inputBackground: panel,
        selectedBackground: active,
        selectedForeground: foreground,
        muted: mutedText,
      },
      fileAttachment: {
        background: element,
        foreground,
        border,
        icon: mutedText,
        removeHover: withAlpha(error, 0.12),
      },
      sessions: {
        background,
        foreground,
        mutedForeground: mutedText,
        border,
        hover,
        active,
      },
      modelSelector: {
        background: element,
        foreground,
        border,
        selectedBackground: active,
        selectedForeground: foreground,
      },
      permissions: {
        background: element,
        foreground,
        border,
        allow: success,
        allowBackground: withAlpha(success, 0.12),
        deny: error,
        denyBackground: withAlpha(error, 0.12),
      },
      loading: {
        spinner: primary,
        spinnerTrack: panel,
        skeleton: element,
        shimmer: hover,
      },
      scrollbar: {
        track: "transparent",
        thumb: withAlpha(foreground, isDark ? 0.2 : 0.15),
        thumbHover: withAlpha(foreground, isDark ? 0.34 : 0.25),
      },
      badges: {
        default: { bg: element, fg: foreground, border },
        info: {
          bg: withAlpha(info, 0.12),
          fg: info,
          border: withAlpha(info, 0.35),
        },
        success: {
          bg: withAlpha(success, 0.12),
          fg: success,
          border: withAlpha(success, 0.35),
        },
        warning: {
          bg: withAlpha(warning, 0.12),
          fg: warning,
          border: withAlpha(warning, 0.35),
        },
        error: {
          bg: withAlpha(error, 0.12),
          fg: error,
          border: withAlpha(error, 0.35),
        },
      },
      toast: {
        background: element,
        foreground,
        border,
        success: {
          background: withAlpha(success, 0.12),
          foreground: success,
          border: withAlpha(success, 0.35),
        },
        warning: {
          background: withAlpha(warning, 0.12),
          foreground: warning,
          border: withAlpha(warning, 0.35),
        },
        error: {
          background: withAlpha(error, 0.12),
          foreground: error,
          border: withAlpha(error, 0.35),
        },
        info: {
          background: withAlpha(info, 0.12),
          foreground: info,
          border: withAlpha(info, 0.35),
        },
      },
      emptyState: {
        icon: mutedText,
        title: foreground,
        description: mutedText,
        border,
      },
      table: {
        border,
        headerBackground: element,
        headerForeground: foreground,
        rowHover: hover,
        rowSelected: active,
      },
      charts: { series: [primary, info, success, warning, error] },
      a11y: { focusRing: borderActive, selection: active, highContrast: false },
      shadows: {
        sm: isDark
          ? "0 2px 8px rgba(0, 0, 0, 0.22)"
          : "0 2px 8px rgba(15, 15, 15, 0.08)",
        md: isDark
          ? "0 12px 32px rgba(0, 0, 0, 0.32)"
          : "0 12px 32px rgba(15, 15, 15, 0.12)",
        lg: isDark
          ? "0 24px 56px rgba(0, 0, 0, 0.42)"
          : "0 24px 56px rgba(15, 15, 15, 0.16)",
        focus: `0 0 0 3px ${withAlpha(borderActive, isDark ? 0.35 : 0.25)}`,
      },
      animation: {
        fast: "150ms ease",
        normal: "250ms ease",
        slow: "350ms ease",
        emphasis: "450ms cubic-bezier(0.2, 0.8, 0.2, 1)",
      },
    },
    config: DEFAULT_CONFIG,
  };
}

async function main(): Promise<void> {
  const args = parseArgs(process.argv.slice(2));
  if (!args.inputPath) {
    usage();
    process.exitCode = 1;
    return;
  }

  const raw = JSON.parse(
    await fs.readFile(args.inputPath, "utf8"),
  ) as OpenCodeThemeInput;
  const inputTheme = normalizeInput(raw);
  const generated = [
    {
      fileName: "stylix-dark.json",
      theme: buildTheme(selectMode(inputTheme, "dark"), "dark"),
    },
    {
      fileName: "stylix-light.json",
      theme: buildTheme(selectMode(inputTheme, "light"), "light"),
    },
  ];

  if (args.stdout) {
    console.log(JSON.stringify(generated, null, 2));
    return;
  }

  await fs.mkdir(args.outDir, { recursive: true });
  for (const { fileName, theme } of generated) {
    const outputPath = path.join(args.outDir, fileName);
    await fs.writeFile(
      outputPath,
      `${JSON.stringify(theme, null, 2)}\n`,
      "utf8",
    );
    console.log(`wrote ${outputPath}`);
  }
}

main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(message);
  process.exitCode = 1;
});
