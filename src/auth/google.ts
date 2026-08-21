import { OAuth2Client } from 'google-auth-library';
import logger from '../utils/logger';

/**
 * Verification of Google sign-in tokens.
 *
 * The app performs the interactive sign-in and sends us the resulting ID
 * token. That token is a JWT signed by Google, so the server can establish
 * who the user is without ever handling their password - but ONLY if it is
 * actually verified. Decoding the payload without checking the signature
 * would let anyone log in as anyone by hand-crafting a token, so this always
 * goes through the library's verifier.
 */

export interface GoogleProfile {
  /** Google's stable, unique id for the account ('sub'). */
  googleId: string;
  email: string;
  emailVerified: boolean;
  name: string | null;
  picture: string | null;
}

/**
 * Client ids this server will accept tokens for.
 *
 * Android, iOS and web each get their own OAuth client in the Google console
 * and each mints tokens with its own `aud`, so the list is comma-separated.
 * The Android client id is the one the Flutter app signs in with; the web
 * client id is what `google_sign_in` uses as its `serverClientId`.
 */
const audiences = (): string[] =>
  (process.env.GOOGLE_CLIENT_IDS ?? process.env.GOOGLE_CLIENT_ID ?? '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);

let client: OAuth2Client | null = null;
const getClient = (): OAuth2Client => (client ??= new OAuth2Client());

/** True when the server has been configured to accept Google sign-in. */
export const isGoogleConfigured = (): boolean => audiences().length > 0;

/**
 * Verifies an ID token and returns the profile it asserts.
 *
 * Throws a normal API error rather than the library's, so the route handler
 * can report it like any other failure.
 */
export const verifyGoogleIdToken = async (
  idToken: string
): Promise<GoogleProfile> => {
  const allowed = audiences();

  if (allowed.length === 0) {
    logger.error('Google sign-in attempted but GOOGLE_CLIENT_IDS is not set');
    throw {
      code: 'GOOGLE_NOT_CONFIGURED',
      message: 'Google sign-in is not available right now.',
      status: 503,
    };
  }

  let payload;
  try {
    const ticket = await getClient().verifyIdToken({
      idToken,
      audience: allowed,
    });
    payload = ticket.getPayload();
  } catch (error: any) {
    logger.warn('Google ID token rejected', { error: error?.message });
    throw {
      code: 'INVALID_GOOGLE_TOKEN',
      message: 'Google sign-in failed. Please try again.',
      status: 401,
    };
  }

  if (!payload?.sub) {
    throw {
      code: 'INVALID_GOOGLE_TOKEN',
      message: 'Google sign-in failed. Please try again.',
      status: 401,
    };
  }

  // Google issues tokens for several of its own properties; only accept the
  // ones it actually signed as an account identity.
  const issuer = payload.iss ?? '';
  if (issuer !== 'accounts.google.com' && issuer !== 'https://accounts.google.com') {
    throw {
      code: 'INVALID_GOOGLE_TOKEN',
      message: 'Google sign-in failed. Please try again.',
      status: 401,
    };
  }

  if (!payload.email) {
    throw {
      code: 'GOOGLE_EMAIL_MISSING',
      message: 'Your Google account did not share an email address.',
      status: 400,
    };
  }

  return {
    googleId: payload.sub,
    email: payload.email.toLowerCase(),
    emailVerified: payload.email_verified === true,
    name: payload.name ?? null,
    picture: payload.picture ?? null,
  };
};
