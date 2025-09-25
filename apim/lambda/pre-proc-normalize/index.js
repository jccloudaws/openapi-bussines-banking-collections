// index.js (Node.js 20.x)
import crypto from "node:crypto";
import https from "node:https";
import http from "node:http";
import { SecretsManagerClient, GetSecretValueCommand } from "@aws-sdk/client-secrets-manager";

const NLB_HOST   = process.env.NLB_HOST;               // p.ej. a2fd7c...elb.amazonaws.com
const NLB_PORT   = parseInt(process.env.NLB_PORT || "443", 10);
const NLB_SCHEME = (process.env.NLB_SCHEME || "https").toLowerCase(); // "https" | "http"
const SECRET_NAME = process.env.RSA_KEYS_SECRET_NAME;  // p.ej. "rsa-keys/dev"

// cache simple de secreto entre invocaciones
let cachedKeys = null;

async function getRsaKeys() {
  if (cachedKeys) return cachedKeys;

  const client = new SecretsManagerClient({});
  const out = await client.send(new GetSecretValueCommand({ SecretId: SECRET_NAME }));
  if (!out.SecretString) throw new Error("Secret without SecretString");

  // Se espera: { "public_key_b64": "...","private_key_b64":"..." } (PEM base64-encoded)
  const parsed = JSON.parse(out.SecretString);

  const privPem = Buffer.from(parsed.private_key_b64, "base64").toString("utf8");
  const pubPem  = parsed.public_key_b64 ? Buffer.from(parsed.public_key_b64, "base64").toString("utf8") : null;

  cachedKeys = { privatePem: privPem, publicPem: pubPem };
  return cachedKeys;
}

function rsaDecryptBase64(base64Cipher, privatePem) {
  const buf = Buffer.from(base64Cipher, "base64");
  return crypto.privateDecrypt(
    { key: privatePem, padding: crypto.constants.RSA_PKCS1_PADDING },
    buf
  );
}

function aesCbcDecryptBase64(base64Cipher, keyUtf8, ivUtf8) {
  const key = Buffer.from(keyUtf8, "utf8"); // del payload (ej. 16/24/32 bytes según AES)
  const iv  = Buffer.from(ivUtf8, "utf8");  // 16 bytes
  const cipherBuf = Buffer.from(base64Cipher, "base64");

  const decipher = crypto.createDecipheriv(`aes-${key.length * 8}-cbc`, key, iv);
  const out = Buffer.concat([decipher.update(cipherBuf), decipher.final()]);
  return out;
}

function buildUpstreamUrl(event) {
  // Tomamos el path exactamente como llegó
  const path = event?.rawPath || "/";
  const qs   = event?.rawQueryString ? `?${event.rawQueryString}` : "";
  return `${NLB_SCHEME}://${NLB_HOST}:${NLB_PORT}${path}${qs}`;
}

function chooseAgent() {
  return NLB_SCHEME === "https" ? https : http;
}

export const handler = async (event) => {
  // 1) Entrante
  const method = event?.requestContext?.http?.method || "POST";
  const isB64  = !!event?.isBase64Encoded;
  const rawBody = event?.body ? (isB64 ? Buffer.from(event.body, "base64").toString("utf8") : event.body) : "";

  // 2) Parse y desencriptado "tal cual" tu policy APIM:
  //    body esperado: { encryptionData: <b64>, content: <b64> }
  const incoming = rawBody ? JSON.parse(rawBody) : {};
  const { privatePem } = await getRsaKeys();

  // 2.1) Decrypt RSA del campo encryptionData (obtiene JSON con iv + key)
  const aesKeyJsonStr = rsaDecryptBase64(incoming.encryptionData, privatePem).toString("utf8");
  const aesKeyObj = JSON.parse(aesKeyJsonStr); // { iv: "...", key: "..." }

  // 2.2) Decrypt AES-CBC del campo content (b64) → payload plano
  const decryptedBuf = aesCbcDecryptBase64(incoming.content, aesKeyObj.key, aesKeyObj.iv);
  const decryptedBody = decryptedBuf.toString("utf8");

  // 3) Reenvío al NLB (mismo path+query y método)
  const url = buildUpstreamUrl(event);
  const agent = chooseAgent();

  // Copiamos algunos headers útiles (no reenviamos "host" ni "authorization")
  const headersIn = event?.headers || {};
  const headers = {
    "content-type": headersIn["content-type"] || "application/json",
    "x-original-auth": headersIn["authorization"] || "",
  };

  const upstreamResp = await new Promise((resolve, reject) => {
    const req = agent.request(url, {
      method,
      headers,
      timeout: 15000,
      rejectUnauthorized: false, // desactívalo si tu NLB/target usa TLS público válido
    }, (res) => {
      let data = "";
      res.setEncoding("utf8");
      res.on("data", (chunk) => (data += chunk));
      res.on("end", () => resolve({
        statusCode: res.statusCode || 502,
        headers: Object.fromEntries(Object.entries(res.headers).map(([k,v]) => [k, Array.isArray(v) ? v.join(",") : v])),
        body: data
      }));
    });

    req.on("error", reject);
    if (!["GET","HEAD"].includes(method.toUpperCase())) req.write(decryptedBody);
    req.end();
  });

  // 4) Devuelve tal cual lo que respondió el backend (HTTP API v2)
  return {
    statusCode: upstreamResp.statusCode,
    headers: upstreamResp.headers,
    body: upstreamResp.body,
  };
};
