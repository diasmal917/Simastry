# Co-Star Style Onboarding with Carousel Landing Page

## Summary
Redesign the landing page and onboarding to follow Co-Star's clean, minimal flow while keeping Simastry's existing wallpaper, animations, carousel, and app title.

---

### **Landing Page Changes**

- **Keep**: Wallpaper image, falling stars, shimmer stars, motion parallax, "Simastry" title (italic serif), carousel with feature cards, page indicator
- **Remove**: Email/password fields, Google sign-in button, Apple sign-in button, "Sign In / Create Account" toggle, terms footer — all removed from the landing page
- **Carousel fix**: Remove the dark capsule background behind headline text (e.g. "Predict Their Reply") so it matches the subtitle style — just white text with no background pill
- **New bottom section**: Two simple buttons at the bottom over a subtle gradient fade:
  - **"Get Started"** — gold-styled primary button (same GoldButton style)
  - **"I already have an account"** — plain white text link below it
  - Small terms text at the very bottom

---

### **"Get Started" Flow (New Users)**

A step-by-step birth details flow, one question per screen, with a clean dark background and back navigation:

1. **Birthday screen** — Large title "What's your birthday?", date picker wheel, privacy disclaimer at the bottom: *"We use this to generate your astrological birth chart. We never share or sell your data."*, Continue button
2. **Birth time screen** — Large title "What time were you born?", time picker wheel, "I don't know" toggle option (defaults to noon if unknown), same privacy note, Continue button
3. **Birthplace screen** — Large title "Where were you born?", text field for city/country, note that it's optional, Continue button
4. **Account creation screen** — After birth details are collected, show a clean sign-up screen with: Continue with Apple, Continue with Google, email/password fields with a "Create Account" button
5. After account creation → signs are calculated from birth data → flows into the existing Mode Selection → Companion Setup → Soul Creation sequence

---

### **"I already have an account" Flow (Returning Users)**

- Opens a full screen with the same dark celestial background
- Shows: email + password fields, "Sign In" button, Continue with Apple, Continue with Google
- Back button to return to landing
- After sign-in → loads existing profile and companions → goes to home

---

### **Design Details**

- Each birth detail screen has a consistent layout: back arrow top-left, large bold title, centered input, privacy note in muted text, Continue button at bottom
- Progress dots or step indicator (1 of 3) at the top of birth detail screens
- Same dark celestial aesthetic throughout — no jarring style changes
- Smooth spring transitions between each step
- The existing Sign Selection view (choose signs manually vs. calculate) is still reachable from Mode Selection for users who already know their signs
