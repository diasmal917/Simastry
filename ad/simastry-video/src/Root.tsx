import { Composition } from "remotion";
import { SimastryAd } from "./SimastryAd";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="SimastryAd"
        component={SimastryAd}
        durationInFrames={30 * 45}
        fps={30}
        width={1080}
        height={1920}
      />
      <Composition
        id="SimastryAd-Landscape"
        component={SimastryAd}
        durationInFrames={30 * 45}
        fps={30}
        width={1920}
        height={1080}
      />
    </>
  );
};
