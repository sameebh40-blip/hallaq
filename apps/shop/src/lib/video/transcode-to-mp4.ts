import { spawn } from "child_process";
import { randomUUID } from "crypto";
import { promises as fs } from "fs";
import os from "os";
import path from "path";

async function ffmpegPath() {
  const mod = await import("@ffmpeg-installer/ffmpeg");
  const p = (mod.default as unknown as { path?: string }).path;
  if (!p) throw new Error("FFmpeg not available");
  return p;
}

async function run(cmd: string, args: string[]) {
  await new Promise<void>((resolve, reject) => {
    const child = spawn(cmd, args, { windowsHide: true });
    let err = "";
    child.stderr.on("data", (d) => {
      err += String(d);
      if (err.length > 30000) err = err.slice(-30000);
    });
    child.on("error", reject);
    child.on("close", (code) => {
      if (code === 0) resolve();
      else reject(new Error(err || `ffmpeg exit code ${code}`));
    });
  });
}

export async function transcodeVideoToMp4_720p(input: Uint8Array, maxSeconds: number) {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), "hallaq-reel-"));
  const inPath = path.join(dir, `${randomUUID()}.input`);
  const outPath = path.join(dir, `${randomUUID()}.mp4`);
  try {
    await fs.writeFile(inPath, input);
    await run(await ffmpegPath(), [
      "-y",
      "-i",
      inPath,
      "-t",
      String(maxSeconds),
      "-vf",
      "scale='min(1280,iw)':'min(720,ih)':force_original_aspect_ratio=decrease,scale=trunc(iw/2)*2:trunc(ih/2)*2",
      "-c:v",
      "libx264",
      "-preset",
      "veryfast",
      "-crf",
      "28",
      "-pix_fmt",
      "yuv420p",
      "-c:a",
      "aac",
      "-b:a",
      "128k",
      "-movflags",
      "+faststart",
      outPath
    ]);
    const bytes = await fs.readFile(outPath);
    return new Uint8Array(bytes);
  } finally {
    try {
      await fs.rm(dir, { recursive: true, force: true });
    } catch {}
  }
}
