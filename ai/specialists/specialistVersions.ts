import type { SpecialistId } from "../../supabase/functions/companion-reply/specialistPrompt.ts";

export type SpecialistVersionInfo = {
  harnessVersion: string;
  programVersion: string;
  evalVersion: string;
};

export const specialistVersions: Record<SpecialistId, SpecialistVersionInfo> = {
  "leyla-western": {
    harnessVersion: "1.0.0",
    programVersion: "1.0.0",
    evalVersion: "1.0.0",
  },
  "mateo-vedic": {
    harnessVersion: "1.0.0",
    programVersion: "1.0.0",
    evalVersion: "1.0.0",
  },
  "naomi-chinese": {
    harnessVersion: "1.0.0",
    programVersion: "1.0.0",
    evalVersion: "1.0.0",
  },
  "elias-ancient": {
    harnessVersion: "1.0.0",
    programVersion: "1.0.0",
    evalVersion: "1.0.0",
  },
  "nadia-evolutionary": {
    harnessVersion: "1.0.0",
    programVersion: "1.0.0",
    evalVersion: "1.0.0",
  },
};
