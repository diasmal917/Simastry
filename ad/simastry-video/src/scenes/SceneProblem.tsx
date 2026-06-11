import React, { CSSProperties } from "react";
import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { colors } from "../styles";

const ChatBubble: React.FC<{
  text: string;
  side: "left" | "right";
  appearFrame: number;
}> = ({ text, side, appearFrame }) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(frame, [appearFrame, appearFrame + 15], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const y = interpolate(frame, [appearFrame, appearFrame + 15], [25, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const isRight = side === "right";

  const style: CSSProperties = {
    maxWidth: 700,
    padding: "30px 40px",
    borderRadius: 30,
    fontSize: 34,
    lineHeight: 1.5,
    margin: "12px 0",
    opacity,
    transform: `translateY(${y}px)`,
    alignSelf: isRight ? "flex-end" : "flex-start",
    color: colors.text,
    ...(isRight
      ? {
          background:
            "linear-gradient(135deg, rgba(185,155,75,0.2), rgba(185,155,75,0.08))",
          border: "1px solid rgba(185,155,75,0.2)",
          borderBottomRightRadius: 8,
        }
      : {
          background: "rgba(255,255,255,0.08)",
          border: "1px solid rgba(255,255,255,0.06)",
          borderBottomLeftRadius: 8,
        }),
  };

  return <div style={style}>{text}</div>;
};

export const SceneProblem: React.FC = () => {
  const frame = useCurrentFrame();

  const emojiScale = interpolate(frame, [75, 85], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const emojiOpacity = interpolate(frame, [75, 82], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Typing dots animation
  const dotsOpacity = interpolate(frame, [50, 60], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const dotPhase = frame * 0.15;
  const dot1 = 0.3 + 0.7 * Math.abs(Math.sin(dotPhase));
  const dot2 = 0.3 + 0.7 * Math.abs(Math.sin(dotPhase + 1));
  const dot3 = 0.3 + 0.7 * Math.abs(Math.sin(dotPhase + 2));

  return (
    <AbsoluteFill
      style={{
        display: "flex",
        flexDirection: "column",
        justifyContent: "center",
        padding: "0 80px",
      }}
    >
      <ChatBubble
        text="Hey, can we talk about the project?"
        side="left"
        appearFrame={15}
      />
      <ChatBubble
        text="Sure, what's up? 😊"
        side="right"
        appearFrame={35}
      />

      {/* Typing indicator */}
      <div
        style={{
          maxWidth: 700,
          padding: "30px 40px",
          borderRadius: 30,
          borderBottomLeftRadius: 8,
          background: "rgba(255,255,255,0.08)",
          border: "1px solid rgba(255,255,255,0.06)",
          margin: "12px 0",
          alignSelf: "flex-start",
          opacity: dotsOpacity,
          display: "flex",
          gap: 8,
        }}
      >
        {[dot1, dot2, dot3].map((o, i) => (
          <div
            key={i}
            style={{
              width: 14,
              height: 14,
              borderRadius: "50%",
              background: colors.muted,
              opacity: o,
            }}
          />
        ))}
      </div>

      <div
        style={{
          fontSize: 100,
          textAlign: "center",
          marginTop: 40,
          opacity: emojiOpacity,
          transform: `scale(${emojiScale})`,
        }}
      >
        😰
      </div>
    </AbsoluteFill>
  );
};
