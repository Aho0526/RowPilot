import 'reflect-metadata';
import * as jose from 'jose';
import { X509Certificate } from '@peculiar/x509';

/**
 * Apple Root CA - G3 の SHA-256 フィンガープリント。
 * App Store の署名付きデータ (JWS) は必ず Apple Root CA - G3 を頂点とする
 * 証明書チェーン(x5c)で署名されている。
 * https://www.apple.com/certificateauthority/AppleRootCA-G3.cer
 */
export const APPLE_ROOT_CA_G3_SHA256 =
  "63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179";

function base64ToBytes(b64) {
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes;
}

function base64UrlDecodeToString(str) {
  let b64 = str.replace(/-/g, '+').replace(/_/g, '/');
  while (b64.length % 4) b64 += '=';
  return new TextDecoder().decode(base64ToBytes(b64));
}

async function sha256Hex(bytes) {
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

/**
 * App Store が発行した JWS (署名付きトランザクション / 通知ペイロード) を検証し、
 * ペイロードを返す。検証に失敗した場合は例外を投げる。
 *
 * 検証内容:
 *  1. alg が ES256 であること
 *  2. x5c チェーンの最後の証明書が Apple Root CA - G3 であること (フィンガープリント固定)
 *  3. チェーン内の各証明書が、1つ上位の証明書で署名されていること
 *  4. 中間・ルート証明書が有効期間内であること
 *  5. リーフ証明書の公開鍵で JWS の署名が正しいこと
 *
 * ※ リーフ証明書の有効期限は検証しない。過去に署名されたトランザクションを
 *    後から再提出するケース(アプリ再起動時の再同期等)があるため。
 *
 * @param {string} jws
 * @param {{ rootSha256?: string, now?: Date }} [opts] テスト用の上書き
 */
export async function verifyAppleJWS(jws, opts = {}) {
  const rootSha256 = (opts.rootSha256 || APPLE_ROOT_CA_G3_SHA256).toLowerCase();
  const now = opts.now || new Date();

  if (typeof jws !== 'string') throw new Error('Invalid JWS');
  const parts = jws.split('.');
  if (parts.length !== 3) throw new Error('Invalid JWS');

  const header = JSON.parse(base64UrlDecodeToString(parts[0]));
  if (header.alg !== 'ES256') throw new Error('Unsupported alg');
  if (!Array.isArray(header.x5c) || header.x5c.length < 2) {
    throw new Error('Invalid x5c chain');
  }

  // 2. ルート証明書のフィンガープリント固定
  const rootB64 = header.x5c[header.x5c.length - 1];
  const rootFp = await sha256Hex(base64ToBytes(rootB64));
  if (rootFp !== rootSha256) throw new Error('Untrusted root certificate');

  // 3, 4. チェーン検証
  const certs = header.x5c.map((c) => new X509Certificate(c));
  for (let i = 0; i < certs.length - 1; i++) {
    const ok = await certs[i].verify({
      publicKey: certs[i + 1].publicKey,
      signatureOnly: true,
    });
    if (!ok) throw new Error('Certificate chain signature mismatch');
  }
  for (let i = 1; i < certs.length; i++) {
    if (now < certs[i].notBefore || now > certs[i].notAfter) {
      throw new Error('Certificate expired');
    }
  }

  // 5. JWS 署名の検証 (リーフ証明書の公開鍵)
  const pem = `-----BEGIN CERTIFICATE-----\n${header.x5c[0].match(/.{1,64}/g).join('\n')}\n-----END CERTIFICATE-----`;
  const publicKey = await jose.importX509(pem, 'ES256');
  const { payload } = await jose.compactVerify(jws, publicKey);
  return JSON.parse(new TextDecoder().decode(payload));
}
