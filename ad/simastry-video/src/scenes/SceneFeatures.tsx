import React, { CSSProperties } from "react";
import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { colors, glassMorphism } from "../styles";

interface Feature {
  icon: string;
  title: string;
  description: string;
  appearFrame: number;
  direction: "left" | "right";
}

const features: Feature[] = [
  {
    icon: "🔮",
    title: "Predict Their Reply",
    description: "AI + astrology predicts what anyone will say next",
    appearFrame: 15,
    direction: "left",
  },
  {
    icon: "💬",
    title: "Communication Guides",
    description: "Know exactly how to approach your boss, partner, or family",
    appearFrame: 50,
    direction: "right",
  },
  {
    icon: "⭐",
    title: "Compatibility Breakdown",
    description: "Sun, Moon & Rising analysis with real explanations",
    appearFrame: 85,
    direction: "left",
  },
];

const FeatureCard: React.FC<{ feature: Feature }> = ({ feature }) => {
  const frame = useCurrentFrame();
  const { appearFrame, direction } = feature;

  const opacity = interpolate(frame, [appearFrame, appearFrame + 18], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const translateX = interpolate(
    frame,
    [appearFrame, appearFrame + 18],
    [direction === "left" ? -80 : 80, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
  );

  return (
    <div
      style={{
        ...glassMorphism,
        width: 860,
        padding: "45px 50px",
        display: "flex",
        alignItems: "center",
        gap: 35,
        opacity,
        transform: `translateX(${translateX}px)`,
      }}
    >
      <div style={{ fontSize: 64, flexShrink: 0, width: 100, textAlign: "center" }}>
        {feature.icon}
      </div>
      <div>
        <div
          style={{
            fontSize: 36,
            fontWeight: 600,
            color: colors.goldLight,
            marginBottom: 8,
          }}
        >
          {feature.title}
        </div>
        <div style={{ fontSize: 26, color: colors.muted, lineHeight: 1.4 }}>
          {feature.description}
        </div>
      </div>
    </div>
  );
};

export const SceneFeatures: React.FC = () => {
  return (
    <AbsoluteFill
      style={{
        alignItems: "center",
        justifyContent: "center",
        gap: 50,
      }}
    >
      {features.map((f, i) => (
        <FeatureCard key={i} feature={f} />
      ))}
    </AbsoluteFill>
  );
};
