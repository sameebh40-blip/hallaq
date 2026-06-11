import { spawn } from "child_process";
import { randomUUID } from "crypto";
import { promises as fs } from "fs";
import os from "os";
import path from "path";

import { MAX_ADMIN_VIDEO_BYTES } from "@/lib/media/upload-constraints";

async function ffmpegPath() {
  try {
    const envPath = String(process.env.FFMPEG_PATH ?? "").trim();
    if (envPath) {
      await fs.access(envPath);
      return envPath;
    }
  } catch {}
  try {
    const mod = await import("@ffmpeg-installer/ffmpeg");
    const p = (mod.default as unknown as { path?: string }).path;
    const resolved = p && String(p).trim() ? String(p) : "";
    if (!resolved) return null;
    await fs.access(resolved);
    return resolved;
  } catch {
    return null;
  }
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

export async function transcodeVideoToMp4_720p(input: Uint8Array, maxSeconds = 20) {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), "hallaq-reel-"));
  const inPath = path.join(dir, `${randomUUID()}.input`);
  try {
    await fs.writeFile(inPath, input);
    let smallest: Uint8Array | null = null;
    const ffmpeg = await ffmpegPath();
    if (!ffmpeg) throw new Error("ffmpeg_not_available");

    const attempts = [
      { scale: "1280:720", crf: "28", audioBitrate: "128k" },
      { scale: "1280:720", crf: "32", audioBitrate: "96k" },
      { scale: "960:540", crf: "34", audioBitrate: "96k" },
      { scale: "854:480", crf: "36", audioBitrate: "80k" },
    ];

    for (const [index, attempt] of attempts.entries()) {
      const outPath = path.join(dir, `${index}-${randomUUID()}.mp4`);
      await run(ffmpeg, [
        "-y",
        "-i",
        inPath,
        "-t",
        String(maxSeconds),
        "-vf",
        `scale='min(${attempt.scale.split(":")[0]},iw)':'min(${attempt.scale.split(":")[1]},ih)':force_original_aspect_ratio=decrease,scale=trunc(iw/2)*2:trunc(ih/2)*2`,
        "-c:v",
        "libx264",
        "-preset",
        "veryfast",
        "-crf",
        attempt.crf,
        "-pix_fmt",
        "yuv420p",
        "-c:a",
        "aac",
        "-b:a",
        attempt.audioBitrate,
        "-movflags",
        "+faststart",
        outPath
      ]);
      const bytes = new Uint8Array(await fs.readFile(outPath));
      if (!smallest || bytes.byteLength < smallest.byteLength) {
        smallest = bytes;
      }
      if (bytes.byteLength <= MAX_ADMIN_VIDEO_BYTES) {
        return bytes;
      }
    }

    if (smallest) {
      throw new Error("Video is still too large after compression. Please choose a shorter video.");
    }

    throw new Error("Could not process this video for upload.");
  } finally {
    try {
      await fs.rm(dir, { recursive: true, force: true });
    } catch {}
  }
}
