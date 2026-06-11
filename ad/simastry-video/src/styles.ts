import { CSSProperties } from "react";

export const colors = {
  gold: "#B99B4B",
  goldLight: "#D7B969",
  goldDark: "#917837",
  midnight: "#05050A",
  surface: "#0C0E16",
  celestialBlue: "#4A90D9",
  text: "#F0F2F5",
  muted: "#94A3B8",
};

export const fullScreen: CSSProperties = {
  position: "absolute",
  inset: 0,
  display: "flex",
  flexDirection: "column",
  alignItems: "center",
  justifyContent: "center",
  overflow: "hidden",
};

export const glassMorphism: CSSProperties = {
  background: "rgba(255,255,255,0.04)",
  border: `1px solid rgba(185,155,75,0.15)`,
  borderRadius: 30,
  backdropFilter: "blur(20px)",
};
