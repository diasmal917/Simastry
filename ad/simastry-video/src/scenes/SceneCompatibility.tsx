import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { colors } from "../styles";

export const SceneCompatibility: React.FC = () => {
  const frame = useCurrentFrame();

  const titleOpacity = interpolate(frame, [10, 22], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const signsOpacity = interpolate(frame, [25, 37], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const signsY = interpolate(frame, [25, 37], [20, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const heartScale = interpolate(frame, [40, 52], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const ringOpacity = interpolate(frame, [55, 67], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Animated score counter
  const scoreTarget = 87;
  const scoreValue = Math.min(
    scoreTarget,
    Math.round(
      interpolate(frame, [65, 100], [0, scoreTarget], {
        extrapolateLeft: "clamp",
        extrapolateRight: "clamp",
      })
    )
  );

  // Ring rotation for the arc effect
  const ringRotation = interpolate(frame, [65, 105], [-90, 200], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const detailOpacity = interpolate(frame, [105, 118], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const detailY = interpolate(frame, [105, 118], [20, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const signBadgeStyle: React.CSSProperties = {
    width: 160,
    height: 160,
    borderRadius: "50%",
    background: "rgba(255,255,255,0.05)",
    border: "2px solid rgba(185,155,75,0.3)",
    display: "flex",
    flexDirection: "column",
    alignItems: "center",
    justifyContent: "center",
    gap: 8,
  };

  return (
    <AbsoluteFill
      style={{
        alignItems: "center",
        justifyContent: "center",
        gap: 30,
      }}
    >
      {/* Title */}
      <div
        style={{
          fontSize: 38,
          color: colors.muted,
          opacity: titleOpacity,
        }}
      >
        Your Compatibility
      </div>

      {/* Signs row */}
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: 50,
          opacity: signsOpacity,
          transform: `translateY(${signsY}px)`,
        }}
      >
        <div style={signBadgeStyle}>
          <span style={{ fontSize: 56 }}>♌</span>
          <span style={{ fontSize: 22, color: colors.goldLight, fontWeight: 600 }}>
            Leo
          </span>
        </div>

        <div
          style={{
            fontSize: 60,
            transform: `scale(${heartScale})`,
          }}
        >
          💛
        </div>

        <div style={signBadgeStyle}>
          <span style={{ fontSize: 56 }}>♒</span>
          <span style={{ fontSize: 22, color: colors.goldLight, fontWeight: 600 }}>
            Aquarius
          </span>
        </div>
      </div>

      {/* Score ring */}
      <div
        style={{
          width: 260,
          height: 260,
          borderRadius: "50%",
          border: "6px solid rgba(185,155,75,0.15)",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          position: "relative",
          opacity: ringOpacity,
        }}
      >
        {/* Animated arc */}
        <svg
          width={272}
          height={272}
          style={{ position: "absolute", top: -6, left: -6 }}
        >
          <circle
            cx={136}
            cy={136}
            r={127}
            fill="none"
            stroke={colors.gold}
            strokeWidth={6}
            strokeDasharray={`${(scoreValue / 100) * 798} 798`}
            strokeLinecap="round"
            transform="rotate(-90 136 136)"
            style={{ transition: "stroke-dasharray 0.1s" }}
          />
        </svg>
        <span style={{ fontSize: 72, fontWeight: 700, color: colors.goldLight }}>
          {scoreValue}%
        </span>
        <span
          style={{
            fontSize: 24,
            color: colors.muted,
            marginTop: -5,
          }}
        >
          match
        </span>
      </div>

      {/* Detail text */}
      <div
        style={{
          fontSize: 28,
          color: colors.text,
          textAlign: "center",
          maxWidth: 700,
          lineHeight: 1.5,
          opacity: detailOpacity,
          transform: `translateY(${detailY}px)`,
        }}
      >
        Your{" "}
        <span style={{ color: colors.goldLight, fontWeight: 600 }}>
          Moon signs
        </span>{" "}
        create deep emotional understanding.
        <br />
        Communication flows naturally between you.
      </div>
    </AbsoluteFill>
  );
};
