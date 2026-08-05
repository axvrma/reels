import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import * as argon2 from 'argon2';
import * as jose from 'jose';
import crypto from 'crypto';
import { v4 as uuidv4 } from 'uuid';
import db from '../db/index';
import { authenticate, requireActiveUser } from '../middleware/auth';
import { z } from 'zod';

const router = Router();

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5, // limit each IP to 5 requests per windowMs
  message: { error: { code: 'TOO_MANY_REQUESTS', message: 'Too many login attempts, please try again later.' } }
});

const refreshLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  message: { error: { code: 'TOO_MANY_REQUESTS', message: 'Too many refresh attempts.' } }
});

const secret = new TextEncoder().encode(
  process.env.AUTH_ACCESS_TOKEN_SECRET || 'fallback-secret-do-not-use-in-prod'
);
const pepper = process.env.AUTH_REFRESH_TOKEN_PEPPER || 'fallback-pepper';
const accessTtlMinutes = parseInt(process.env.AUTH_ACCESS_TOKEN_TTL_MINUTES || '1440', 10);
const refreshTtlDays = parseInt(process.env.AUTH_REFRESH_TOKEN_TTL_DAYS || '30', 10);
const cookieName = process.env.AUTH_COOKIE_NAME || 'reels_refresh';
const issuer = process.env.AUTH_ISSUER || 'reels-private-media';

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string(),
  clientType: z.enum(['dashboard', 'mobile']),
  deviceName: z.string().optional()
});

const signupSchema = z.object({
  email: z.string().email(),
  password: z.string().min(6),
  clientType: z.enum(['dashboard', 'mobile']),
  deviceName: z.string().optional()
});

const generateAccessToken = async (userId: string) => {
  return await new jose.SignJWT({})
    .setProtectedHeader({ alg: 'HS256' })
    .setSubject(userId)
    .setIssuer(issuer)
    .setIssuedAt()
    .setExpirationTime(`${accessTtlMinutes}m`)
    .sign(secret);
};

const createRefreshToken = (userId: string, clientType: string, deviceName: string | undefined, req: any) => {
  const plainToken = crypto.randomBytes(32).toString('hex');
  const tokenHash = crypto.createHash('sha256').update(plainToken + pepper).digest('hex');
  const tokenId = uuidv4();
  const expiresAt = new Date();
  expiresAt.setDate(expiresAt.getDate() + refreshTtlDays);

  const finalDeviceName = deviceName || clientType;

  db.prepare(`
    INSERT INTO refresh_tokens (id, user_id, token_hash, device_name, user_agent, expires_at, created_at)
    VALUES (?, ?, ?, ?, ?, ?, datetime('now'))
  `).run(tokenId, userId, tokenHash, finalDeviceName, req.headers['user-agent'] || '', expiresAt.toISOString());

  return { plainToken, tokenId, expiresAt };
};

router.post('/signup', async (req, res) => {
  try {
    const { email, password, clientType, deviceName } = signupSchema.parse(req.body);

    const existingUser = db.prepare('SELECT id FROM users WHERE email = ?').get(email);
    if (existingUser) {
      res.status(400).json({ error: { code: 'USER_EXISTS', message: 'User already exists.' } });
      return;
    }

    const passwordHash = await argon2.hash(password);
    const userId = uuidv4();
    
    db.prepare(`
      INSERT INTO users (id, email, password_hash, role, is_active, created_at, updated_at, last_login_at)
      VALUES (?, ?, ?, 'viewer', 1, datetime('now'), datetime('now'), datetime('now'))
    `).run(userId, email, passwordHash);

    const accessToken = await generateAccessToken(userId);
    const { plainToken, expiresAt } = createRefreshToken(userId, clientType, deviceName, req);

    const userProfile = { id: userId, email, role: 'viewer' };

    if (clientType === 'dashboard') {
      res.cookie(cookieName, plainToken, {
        httpOnly: true,
        sameSite: 'strict',
        secure: process.env.NODE_ENV === 'production',
        expires: expiresAt
      });
      res.json({ accessToken, user: userProfile });
    } else {
      res.json({ accessToken, refreshToken: plainToken, expiresAt, user: userProfile });
    }
  } catch (error) {
    if (error instanceof z.ZodError) {
      res.status(400).json({ error: { code: 'BAD_REQUEST', message: 'Invalid input.' } });
      return;
    }
    console.error(error);
    res.status(500).json({ error: { code: 'INTERNAL_ERROR', message: 'Server error.' } });
  }
});

router.post('/login', loginLimiter, async (req, res) => {
  try {
    const { email, password, clientType, deviceName } = loginSchema.parse(req.body);

    const user = db.prepare('SELECT * FROM users WHERE email = ?').get(email) as any;
    if (!user) {
      res.status(401).json({ error: { code: 'INVALID_CREDENTIALS', message: 'Email or password is incorrect.' } });
      return;
    }

    const validPassword = await argon2.verify(user.password_hash, password);
    if (!validPassword) {
      res.status(401).json({ error: { code: 'INVALID_CREDENTIALS', message: 'Email or password is incorrect.' } });
      return;
    }

    if (!user.is_active) {
      res.status(403).json({ error: { code: 'FORBIDDEN', message: 'Account is deactivated.' } });
      return;
    }

    db.prepare("UPDATE users SET last_login_at = datetime('now') WHERE id = ?").run(user.id);

    const accessToken = await generateAccessToken(user.id);
    const { plainToken, expiresAt } = createRefreshToken(user.id, clientType, deviceName, req);

    const userProfile = { id: user.id, email: user.email, role: user.role };

    if (clientType === 'dashboard') {
      res.cookie(cookieName, plainToken, {
        httpOnly: true,
        sameSite: 'strict',
        secure: process.env.NODE_ENV === 'production',
        expires: expiresAt
      });
      res.json({ accessToken, user: userProfile });
    } else {
      res.json({ accessToken, refreshToken: plainToken, expiresAt, user: userProfile });
    }
  } catch (error) {
    if (error instanceof z.ZodError) {
      res.status(400).json({ error: { code: 'BAD_REQUEST', message: 'Invalid input.' } });
      return;
    }
    console.error(error);
    res.status(500).json({ error: { code: 'INTERNAL_ERROR', message: 'Server error.' } });
  }
});

router.post('/refresh', refreshLimiter, async (req, res) => {
  try {
    let plainToken = req.cookies?.[cookieName];
    let clientType = 'dashboard';

    if (!plainToken) {
      const { refreshToken } = req.body;
      if (refreshToken) {
        plainToken = refreshToken;
        clientType = 'mobile';
      }
    }

    if (!plainToken) {
      res.status(401).json({ error: { code: 'UNAUTHORIZED', message: 'No refresh token provided.' } });
      return;
    }

    const tokenHash = crypto.createHash('sha256').update(plainToken + pepper).digest('hex');
    
    const dbToken = db.prepare('SELECT * FROM refresh_tokens WHERE token_hash = ?').get(tokenHash) as any;
    if (!dbToken) {
      res.status(401).json({ error: { code: 'UNAUTHORIZED', message: 'Invalid refresh token.' } });
      return;
    }

    if (dbToken.revoked_at || dbToken.replaced_by_token_id) {
      // Token reuse detected. Revoke all tokens for this user.
      db.prepare("UPDATE refresh_tokens SET revoked_at = datetime('now') WHERE user_id = ? AND revoked_at IS NULL").run(dbToken.user_id);
      res.status(401).json({ error: { code: 'UNAUTHORIZED', message: 'Invalid refresh token.' } });
      return;
    }

    if (new Date(dbToken.expires_at) < new Date()) {
      res.status(401).json({ error: { code: 'UNAUTHORIZED', message: 'Refresh token expired.' } });
      return;
    }

    const user = db.prepare('SELECT * FROM users WHERE id = ?').get(dbToken.user_id) as any;
    if (!user || !user.is_active) {
      res.status(401).json({ error: { code: 'UNAUTHORIZED', message: 'User inactive or not found.' } });
      return;
    }

    // Rotate token
    db.prepare('UPDATE refresh_tokens SET replaced_by_token_id = ? WHERE id = ?').run('pending', dbToken.id);
    const { plainToken: newPlainToken, expiresAt, tokenId: newTokenId } = createRefreshToken(user.id, clientType, undefined, req);
    db.prepare('UPDATE refresh_tokens SET replaced_by_token_id = ? WHERE id = ?').run(newTokenId, dbToken.id);

    const accessToken = await generateAccessToken(user.id);
    const userProfile = { id: user.id, email: user.email, role: user.role };

    if (clientType === 'dashboard') {
      res.cookie(cookieName, newPlainToken, {
        httpOnly: true,
        sameSite: 'strict',
        secure: process.env.NODE_ENV === 'production',
        expires: expiresAt
      });
      res.json({ accessToken, user: userProfile });
    } else {
      res.json({ accessToken, refreshToken: newPlainToken, expiresAt, user: userProfile });
    }

  } catch (error) {
    console.error(error);
    res.status(500).json({ error: { code: 'INTERNAL_ERROR', message: 'Server error.' } });
  }
});

router.post('/logout', authenticate, (req, res) => {
  let plainToken = req.cookies?.[cookieName];
  if (!plainToken) {
    plainToken = req.body.refreshToken;
  }

  if (plainToken) {
    const tokenHash = crypto.createHash('sha256').update(plainToken + pepper).digest('hex');
    db.prepare("UPDATE refresh_tokens SET revoked_at = datetime('now') WHERE token_hash = ?").run(tokenHash);
  }

  res.clearCookie(cookieName);
  res.json({ success: true });
});

router.post('/logout-all', authenticate, (req, res) => {
  db.prepare("UPDATE refresh_tokens SET revoked_at = datetime('now') WHERE user_id = ? AND revoked_at IS NULL").run(req.user!.id);
  res.clearCookie(cookieName);
  res.json({ success: true });
});

router.get('/me', authenticate, requireActiveUser, (req, res) => {
  res.json({ user: req.user });
});

router.get('/sessions', authenticate, requireActiveUser, (req, res) => {
  try {
    const isAdmin = req.user!.role === 'admin';
    let query = `
      SELECT r.id, r.user_id, r.device_name, r.user_agent, r.created_at, r.expires_at,
             u.email, u.role
      FROM refresh_tokens r
      JOIN users u ON r.user_id = u.id
      WHERE r.revoked_at IS NULL AND r.replaced_by_token_id IS NULL AND r.expires_at > datetime('now')
    `;
    let params: any[] = [];
    if (!isAdmin) {
      query += ' AND r.user_id = ?';
      params.push(req.user!.id);
    }
    query += ' ORDER BY u.email ASC, r.created_at DESC';
    
    const sessions = db.prepare(query).all(...params);
    res.json({ sessions });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: { code: 'INTERNAL_ERROR', message: 'Server error.' } });
  }
});

router.delete('/sessions/:id', authenticate, requireActiveUser, (req, res) => {
  try {
    const sessionId = req.params.id;
    const session = db.prepare('SELECT user_id FROM refresh_tokens WHERE id = ?').get(sessionId) as any;
    
    if (!session) {
      res.status(404).json({ error: { code: 'NOT_FOUND', message: 'Session not found.' } });
      return;
    }
    
    if (session.user_id !== req.user!.id && req.user!.role !== 'admin') {
      res.status(403).json({ error: { code: 'FORBIDDEN', message: 'Not authorized.' } });
      return;
    }
    
    db.prepare("UPDATE refresh_tokens SET revoked_at = datetime('now') WHERE id = ?").run(sessionId);
    res.json({ success: true });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: { code: 'INTERNAL_ERROR', message: 'Server error.' } });
  }
});

export default router;
