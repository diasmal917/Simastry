import React from "react";
import {
  AbsoluteFill,
  interpolate,
  useCurrentFrame,
  spring,
  useVideoConfig,
} from "remotion";
import { colors } from "../styles";

export const SceneHook: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const textOpacity = interpolate(frame, [10, 25], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const textY = interpolate(frame, [10, 25], [40, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const subOpacity = interpolate(frame, [50, 65], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const subY = interpolate(frame, [50, 65], [25, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill
      style={{
        alignItems: "center",
        justifyContent: "center",
        padding: "0 60px",
      }}
    >
      <div
        style={{
          fontSize: 72,
          fontWeight: 700,
          textAlign: "center",
          lineHeight: 1.15,
          background: `linear-gradient(135deg, ${colors.text} 0%, ${colors.goldLight} 50%, ${colors.gold} 100%)`,
          WebkitBackgroundClip: "text",
          WebkitTextFillColor: "transparent",
          backgroundClip: "text",
          opacity: textOpacity,
          transform: `translateY(${textY}px)`,
        }}
      >
        Ever wish you knew
        <br />
        what they were
        <br />
        really thinking?
      </div>
      <div
        style={{
          fontSize: 36,
          color: colors.muted,
          marginTop: 30,
          textAlign: "center",
          opacity: subOpacity,
          transform: `translateY(${subY}px)`,
        }}
      >
        There's an app for that.
      </div>
    </AbsoluteFill>
  );
};
