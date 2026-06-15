import { GoogleGenerativeAI } from "@google/generative-ai";

export interface ReceiptAnalysis {
  amount: number | null;
  currency: string | null;
  date: string | null;
  merchant: string | null;
  suggestedCategory: string | null;
  description: string | null;
  lineItems: Array<{ description: string; amount: number | null }>;
}

const CATEGORIES = [
  "Groceries",
  "Transport",
  "Healthcare",
  "Clothing",
  "Activities",
  "Personal care",
  "Other",
];

export async function analyzeReceiptFromImage(
  genAI: GoogleGenerativeAI,
  imageBuffer: Buffer,
  mimeType: string,
): Promise<ReceiptAnalysis> {
  const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });

  const prompt = `Analyze this receipt image and extract expense information.
Return ONLY valid JSON with this exact structure (no markdown, no code fences):
{
  "amount": number or null (total amount paid),
  "currency": "NOK" or other ISO currency code or null,
  "date": "YYYY-MM-DD" or null,
  "merchant": string or null (store name),
  "suggestedCategory": one of ${JSON.stringify(CATEGORIES)} or null,
  "description": string or null (brief summary),
  "lineItems": [{"description": string, "amount": number or null}]
}

If a field cannot be determined, use null. Prefer NOK for Norwegian receipts.`;

  const result = await model.generateContent([
    prompt,
    {
      inlineData: {
        data: imageBuffer.toString("base64"),
        mimeType,
      },
    },
  ]);

  const text = result.response.text().trim();
  const jsonText = text
    .replace(/^```json\s*/i, "")
    .replace(/^```\s*/i, "")
    .replace(/\s*```$/i, "");

  let parsed: Partial<ReceiptAnalysis>;
  try {
    parsed = JSON.parse(jsonText) as Partial<ReceiptAnalysis>;
  } catch {
    throw new Error(`Failed to parse Gemini response: ${text.slice(0, 200)}`);
  }

  return {
    amount: typeof parsed.amount === "number" ? parsed.amount : null,
    currency: parsed.currency ?? "NOK",
    date: parsed.date ?? null,
    merchant: parsed.merchant ?? null,
    suggestedCategory: CATEGORIES.includes(parsed.suggestedCategory ?? "")
      ? parsed.suggestedCategory!
      : "Other",
    description: parsed.description ?? null,
    lineItems: Array.isArray(parsed.lineItems) ? parsed.lineItems : [],
  };
}
