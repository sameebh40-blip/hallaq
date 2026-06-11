import { ImageResponse } from "next/og";

export const size = {
  width: 1200,
  height: 630
};

export const contentType = "image/png";

export default function TwitterImage() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "1200px",
          height: "630px",
          display: "flex",
          flexDirection: "column",
          justifyContent: "center",
          padding: "64px",
          backgroundColor: "#0b0b0f",
          backgroundImage: "radial-gradient(900px 520px at 15% 0%, rgba(212,175,55,0.20), transparent 60%)",
          color: "#ffffff"
        }}
      >
        <div style={{ fontSize: 26, letterSpacing: 8, color: "#d4af37", fontWeight: 800 }}>HALLAQ</div>
        <div style={{ display: "flex", flexDirection: "column", fontSize: 64, lineHeight: 1.05, fontWeight: 800, marginTop: 18 }}>
          <div>HALLAQ</div>
          <div>Production Ready</div>
        </div>
        <div style={{ fontSize: 28, opacity: 0.78, marginTop: 18, maxWidth: 880 }}>
          app.hallaq.com • business.hallaq.com • admin.hallaq.com
        </div>
      </div>
    ),
    size
  );
}
