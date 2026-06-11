import React from "react";
import {
  AbsoluteFill,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { colors } from "../styles";

export const SceneReveal: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const iconScale = spring({ frame: frame - 15, fps, config: { damping: 12, stiffness: 100 } });
  const iconOpacity = interpolate(frame, [15, 25], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const nameOpacity = interpolate(frame, [35, 50], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const nameY = interpolate(frame, [35, 50], [25, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const taglineOpacity = interpolate(frame, [55, 70], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const taglineY = interpolate(frame, [55, 70], [25, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Glow pulse
  const glowIntensity = 0.3 + 0.1 * Math.sin(frame * 0.08);

  return (
    <AbsoluteFill
      style={{
        alignItems: "center",
        justifyContent: "center",
        gap: 20,
      }}
    >
      {/* Icon */}
      <div
        style={{
          width: 180,
          height: 180,
          borderRadius: 40,
          background: `linear-gradient(145deg, ${colors.gold}, ${colors.goldDark})`,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          fontSize: 90,
          boxShadow: `0 0 ${60 + glowIntensity * 80}px rgba(185,155,75,${glowIntensity}), 0 20px 60px rgba(0,0,0,0.5)`,
          transform: `scale(${iconScale})`,
          opacity: iconOpacity,
        }}
      >
        ✨
      </div>

      {/* Name */}
      <div
        style={{
          fontSize: 80,
          fontWeight: 700,
          letterSpacing: 3,
          background: `linear-gradient(135deg, ${colors.goldLight}, ${colors.gold})`,
          WebkitBackgroundClip: "text",
          WebkitTextFillColor: "transparent",
          backgroundClip: "text",
          opacity: nameOpacity,
          transform: `translateY(${nameY}px)`,
          marginTop: 10,
        }}
      >
        Simastry
      </div>

      {/* Tagline */}
      <div
        style={{
          fontSize: 32,
          color: colors.muted,
          textAlign: "center",
          maxWidth: 700,
          lineHeight: 1.5,
          opacity: taglineOpacity,
          transform: `translateY(${taglineY}px)`,
        }}
      >
        Where Astrology Meets Communication
      </div>
    </AbsoluteFill>
  );
};
