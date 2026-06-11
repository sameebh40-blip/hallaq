import { ImageResponse } from "next/og";

export const size = {
  width: 32,
  height: 32
};

export const contentType = "image/png";

export default function Icon() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "32px",
          height: "32px",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          background: "#0b0b0f",
          color: "#d4af37",
          fontSize: 18,
          fontWeight: 800,
          borderRadius: 8
        }}
      >
        H
      </div>
    ),
    size
  );
}

