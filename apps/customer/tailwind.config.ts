import type { Config } from "tailwindcss";

import preset from "@hallaq/ui/tailwind.preset";

const config: Config = {
  content: ["./src/**/*.{ts,tsx}", "../../packages/ui/src/**/*.{ts,tsx}"],
  presets: [preset]
};

export default config;

