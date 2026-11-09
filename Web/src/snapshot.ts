/** Explicit-user-action browser-only PNG export. No upload, no storage. */
export interface CoverRect { x: number; y: number; width: number; height: number }
export function coverRect(
  sourceWidth: number, sourceHeight: number,
  destinationWidth: number, destinationHeight: number
): CoverRect | null {
  if (![sourceWidth, sourceHeight, destinationWidth, destinationHeight].every(
    (n) => Number.isFinite(n) && n > 0
  )) return null;
  const scale = Math.max(destinationWidth / sourceWidth, destinationHeight / sourceHeight);
  const width = scale * sourceWidth;
  const height = scale * sourceHeight;
  return {
    x: (destinationWidth - width) / 2,
    y: (destinationHeight - height) / 2,
    width, height,
  };
}

export async function captureLocalPNG(
  video: HTMLVideoElement,
  overlay: HTMLCanvasElement,
  stage: HTMLElement,
  mirrored: boolean
): Promise<Blob> {
  if (video.readyState < HTMLMediaElement.HAVE_CURRENT_DATA) {
    throw new Error("Camera video is not ready");
  }
  const output = document.createElement("canvas");
  const pixelRatio = Math.min(window.devicePixelRatio || 1, 2);
  // Scale coordinates consistently so the screenshot matches the
  // crop/mirror visible in the stage, including its WebGL overlay.
  const width = Math.max(1, Math.floor(stage.clientWidth));
  const height = Math.max(1, Math.floor(stage.clientHeight));
  output.width = Math.round(width * pixelRatio);
  output.height = Math.round(height * pixelRatio);
  const ctx = output.getContext("2d");
  const rect = coverRect(video.videoWidth, video.videoHeight, width, height);
  if (!ctx || !rect) throw new Error("Cannot create screenshot compositor");
  ctx.scale(pixelRatio, pixelRatio);
  ctx.save();
  if (mirrored) {
    ctx.translate(width, 0);
    ctx.scale(-1, 1);
  }
  ctx.drawImage(video, rect.x, rect.y, rect.width, rect.height);
  ctx.restore();
  // Call ProxySkeletonRenderer.renderForCapture() immediately before
  // this method; it draws the WebGL back buffer in the same task.
  ctx.drawImage(overlay, 0, 0, width, height);
  // A visible non-medical label must accompany any shared screenshot.
  ctx.font = "600 12px system-ui, sans-serif";
  ctx.fillStyle = "rgba(10, 28, 23, 0.78)";
  ctx.fillRect(8, height - 31, Math.min(325, width - 16), 24);
  ctx.fillStyle = "#f4ead5";
  ctx.fillText("MagicMirror · Illustrative 3D proxy / NOT X-ray", 15, height - 14, width - 29);
  return await new Promise<Blob>((resolve, reject) => {
    output.toBlob((blob) => blob ? resolve(blob) : reject(new Error("PNG encoding failed")), "image/png");
  });
}
