import { ImageResponse } from "next/og";
import { createElement as h } from "react";

export const runtime = "edge";

export function GET() {
  const rootStyle = {
    width: "100%",
    height: "100%",
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    background: "#000000"
  } as const;

  const innerStyle = {
    width: 420,
    height: 420,
    borderRadius: 110,
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    background: "#111111",
    border: "18px solid #D4AF37",
    color: "#D4AF37",
    fontSize: 260,
    fontWeight: 800,
    letterSpacing: -8
  } as const;

  return new ImageResponse(
    h("div", { style: rootStyle }, h("div", { style: innerStyle }, "H")),
    { width: 512, height: 512 }
  );
}
