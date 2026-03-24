import React from "react";
import {
  AbsoluteFill,
  Sequence,
  interpolate,
  useCurrentFrame,
} from "remotion";
import { Starfield, ShootingStar, AmbientOrbs } from "./Starfield";
import { SceneHook } from "./scenes/SceneHook";
import { SceneProblem } from "./scenes/SceneProblem";
import { SceneReveal } from "./scenes/SceneReveal";
import { SceneFeatures } from "./scenes/SceneFeatures";
import { SceneCompatibility } from "./scenes/SceneCompatibility";
import { SceneTestimonials } from "./scenes/SceneTestimonials";
import { SceneCTA } from "./scenes/SceneCTA";
import { colors } from "./styles";

// Timeline (at 30fps):
// Scene 1 - Hook:          0s - 5s    (frames 0-150)
// Scene 2 - Problem:       5s - 9s    (frames 150-270)
// Scene 3 - Reveal:        9s - 13s   (frames 270-390)
// Scene 4 - Features:      13s - 18s  (frames 390-540)
// Scene 5 - Compatibility: 18s - 24s  (frames 540-720)
// Scene 6 - Testimonials:  24s - 29s  (frames 720-870)
// Scene 7 - CTA:           29s - 45s  (frames 870-1350)

const FadeTransition: React.FC<{
  children: React.ReactNode;
  durationInFrames: number;
  fadeIn?: number;
  fadeOut?: number;
}> = ({ children, durationInFrames, fadeIn = 15, fadeOut = 15 }) => {
  const frame = useCurrentFrame();

  let opacity = 1;
  if (fadeIn > 0) {
    opacity = Math.min(
      opacity,
      interpolate(frame, [0, fadeIn], [0, 1], {
        extrapolateLeft: "clamp",
        extrapolateRight: "clamp",
      })
    );
  }
  if (fadeOut > 0) {
    opacity = Math.min(
      opacity,
      interpolate(
        frame,
        [durationInFrames - fadeOut, durationInFrames],
        [1, 0],
        { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
      )
    );
  }

  return (
    <AbsoluteFill style={{ opacity }}>
      {children}
    </AbsoluteFill>
  );
};

export const SimastryAd: React.FC = () => {
  return (
    <AbsoluteFill
      style={{
        backgroundColor: colors.midnight,
        fontFamily:
          "'General Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif",
        color: colors.text,
      }}
    >
      {/* Persistent background */}
      <Starfield />
      <AmbientOrbs />
      <ShootingStar startFrame={60} />
      <ShootingStar startFrame={400} />
      <ShootingStar startFrame={800} />
      <ShootingStar startFrame={1100} />

      {/* Scene 1: Hook (0s - 5s) */}
      <Sequence from={0} durationInFrames={150}>
        <FadeTransition durationInFrames={150} fadeIn={0}>
          <SceneHook />
        </FadeTransition>
      </Sequence>

      {/* Scene 2: Problem (5s - 9s) */}
      <Sequence from={150} durationInFrames={120}>
        <FadeTransition durationInFrames={120}>
          <SceneProblem />
        </FadeTransition>
      </Sequence>

      {/* Scene 3: Reveal (9s - 13s) */}
      <Sequence from={270} durationInFrames={120}>
        <FadeTransition durationInFrames={120}>
          <SceneReveal />
        </FadeTransition>
      </Sequence>

      {/* Scene 4: Features (13s - 18s) */}
      <Sequence from={390} durationInFrames={150}>
        <FadeTransition durationInFrames={150}>
          <SceneFeatures />
        </FadeTransition>
      </Sequence>

      {/* Scene 5: Compatibility (18s - 24s) */}
      <Sequence from={540} durationInFrames={180}>
        <FadeTransition durationInFrames={180}>
          <SceneCompatibility />
        </FadeTransition>
      </Sequence>

      {/* Scene 6: Testimonials (24s - 29s) */}
      <Sequence from={720} durationInFrames={150}>
        <FadeTransition durationInFrames={150}>
          <SceneTestimonials />
        </FadeTransition>
      </Sequence>

      {/* Scene 7: CTA (29s - 45s) */}
      <Sequence from={870} durationInFrames={480}>
        <FadeTransition durationInFrames={480} fadeOut={0}>
          <SceneCTA />
        </FadeTransition>
      </Sequence>
    </AbsoluteFill>
  );
};
