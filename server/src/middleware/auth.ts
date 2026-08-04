import { Request, Response, NextFunction } from 'express';
import * as jose from 'jose';
import db from '../db/index';

const secret = new TextEncoder().encode(
  process.env.AUTH_ACCESS_TOKEN_SECRET || 'fallback-secret-do-not-use-in-prod'
);

export interface AuthUser {
  id: string;
  email: string;
  role: string;
  is_active: number;
}

declare global {
  namespace Express {
    interface Request {
      user?: AuthUser;
    }
  }
}

export const authenticate = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  const authHeader = req.headers.authorization;

  let token: string | undefined;

  if (authHeader && authHeader.startsWith('Bearer ')) {
    token = authHeader.split(' ')[1];
  } 
  
  if (!token && req.query.token && typeof req.query.token === 'string') {
    token = req.query.token;
  }

  if (!token) {
    res.status(401).json({ error: { code: 'UNAUTHORIZED', message: 'Missing or invalid authorization token.' } });
    return;
  }

  try {
    const { payload } = await jose.jwtVerify(token, secret, {
      issuer: process.env.AUTH_ISSUER || 'reels-private-media'
    });

    const user = db.prepare('SELECT id, email, role, is_active FROM users WHERE id = ?').get(payload.sub) as AuthUser | undefined;

    if (!user) {
      res.status(401).json({ error: { code: 'UNAUTHORIZED', message: 'User not found.' } });
      return;
    }

    req.user = user;
    next();
  } catch (error) {
    res.status(401).json({ error: { code: 'UNAUTHORIZED', message: 'Token expired or invalid.' } });
    return;
  }
};

export const requireActiveUser = (req: Request, res: Response, next: NextFunction): void => {
  if (!req.user) {
    res.status(401).json({ error: { code: 'UNAUTHORIZED', message: 'Authentication required.' } });
    return;
  }
  if (!req.user.is_active) {
    res.status(403).json({ error: { code: 'FORBIDDEN', message: 'User account is deactivated.' } });
    return;
  }
  next();
};

export const authorizeRoles = (...roles: string[]) => {
  return (req: Request, res: Response, next: NextFunction): void => {
    if (!req.user) {
      res.status(401).json({ error: { code: 'UNAUTHORIZED', message: 'Authentication required.' } });
      return;
    }
    
    if (!roles.includes(req.user.role)) {
      res.status(403).json({ error: { code: 'FORBIDDEN', message: 'Insufficient permissions.' } });
      return;
    }

    next();
  };
};
