import React from "react";
import {
  AbsoluteFill,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { colors } from "../styles";

export const SceneCTA: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const iconScale = spring({
    frame: frame - 15,
    fps,
    config: { damping: 12, stiffness: 100 },
  });
  const iconOpacity = interpolate(frame, [15, 25], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const nameOpacity = interpolate(frame, [28, 40], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const subOpacity = interpolate(frame, [40, 52], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const subY = interpolate(frame, [40, 52], [20, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const buttonScale = spring({
    frame: frame - 55,
    fps,
    config: { damping: 10, stiffness: 80 },
  });
  const buttonOpacity = interpolate(frame, [55, 65], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const freeOpacity = interpolate(frame, [70, 82], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const platformOpacity = interpolate(frame, [80, 92], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Glow pulse on icon
  const glowIntensity = 0.3 + 0.15 * Math.sin(frame * 0.1);

  return (
    <AbsoluteFill
      style={{
        alignItems: "center",
        justifyContent: "center",
        gap: 35,
      }}
    >
      {/* Logo icon */}
      <div
        style={{
          width: 140,
          height: 140,
          borderRadius: 32,
          background: `linear-gradient(145deg, ${colors.gold}, ${colors.goldDark})`,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          fontSize: 72,
          boxShadow: `0 0 ${60 + glowIntensity * 60}px rgba(185,155,75,${glowIntensity})`,
          transform: `scale(${iconScale})`,
          opacity: iconOpacity,
        }}
      >
        ✨
      </div>

      {/* App name */}
      <div
        style={{
          fontSize: 64,
          fontWeight: 700,
          letterSpacing: 2,
          background: `linear-gradient(135deg, ${colors.goldLight}, ${colors.gold})`,
          WebkitBackgroundClip: "text",
          WebkitTextFillColor: "transparent",
          backgroundClip: "text",
          opacity: nameOpacity,
        }}
      >
        Simastry
      </div>

      {/* Subtitle */}
      <div
        style={{
          fontSize: 34,
          color: colors.text,
          textAlign: "center",
          lineHeight: 1.4,
          opacity: subOpacity,
          transform: `translateY(${subY}px)`,
        }}
      >
        Understand everyone
        <br />
        in your life through the stars.
      </div>

      {/* CTA Button */}
      <div
        style={{
          padding: "28px 80px",
          background: `linear-gradient(135deg, ${colors.gold}, ${colors.goldDark})`,
          borderRadius: 60,
          fontSize: 34,
          fontWeight: 700,
          color: colors.midnight,
          letterSpacing: 1,
          boxShadow: "0 8px 40px rgba(185,155,75,0.35)",
          transform: `scale(${buttonScale})`,
          opacity: buttonOpacity,
        }}
      >
        Download Free
      </div>

      {/* Free text */}
      <div
        style={{
          fontSize: 26,
          color: colors.muted,
          opacity: freeOpacity,
        }}
      >
        Free to start · No credit card required
      </div>

      {/* Platform */}
      <div
        style={{
          fontSize: 24,
          color: colors.muted,
          opacity: platformOpacity,
        }}
      >
         Available on iOS
      </div>
    </AbsoluteFill>
  );
};
