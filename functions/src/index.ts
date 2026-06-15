import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { analyzeReceiptFromImage } from "./analyzeReceipt";

const storageBucket = "molly-expenses.firebasestorage.app";

admin.initializeApp({
  storageBucket,
});

const geminiApiKey = defineSecret("GEMINI_API_KEY");

export const analyzeReceipt = onCall(
  {
    secrets: [geminiApiKey],
    region: "europe-west1",
    timeoutSeconds: 60,
    memory: "512MiB",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in");
    }

    const storagePath = request.data?.storagePath as string | undefined;
    if (!storagePath || typeof storagePath !== "string") {
      throw new HttpsError("invalid-argument", "storagePath is required");
    }

    try {
      const bucket = admin.storage().bucket(storageBucket);
      const file = bucket.file(storagePath);
      const [exists] = await file.exists();
      if (!exists) {
        console.error(
          "Receipt not found",
          JSON.stringify({ storageBucket, storagePath }),
        );
        throw new HttpsError("not-found", "Receipt image not found");
      }

      const [buffer] = await file.download();
      const [metadata] = await file.getMetadata();
      const contentType = metadata.contentType ?? "";
      const mimeType = contentType.startsWith("image/")
        ? contentType
        : storagePath.endsWith(".png")
          ? "image/png"
          : storagePath.endsWith(".webp")
            ? "image/webp"
            : "image/jpeg";

      const genAI = new GoogleGenerativeAI(geminiApiKey.value());
      const analysis = await analyzeReceiptFromImage(
        genAI,
        buffer,
        mimeType,
      );

      return {
        success: true,
        analysis,
      };
    } catch (error) {
      console.error("analyzeReceipt error:", error);
      if (error instanceof HttpsError) {
        throw error;
      }
      return {
        success: false,
        error: error instanceof Error ? error.message : "Analysis failed",
      };
    }
  },
);
