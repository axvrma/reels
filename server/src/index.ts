import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import dotenv from 'dotenv';
import path from 'path';
import fs from 'fs';

dotenv.config();

const app = express();
const port = process.env.PORT || 3000;
const host = process.env.HOST || '127.0.0.1';

app.use(helmet({
  crossOriginResourcePolicy: { policy: "cross-origin" }
}));
app.use(cors({
  origin: true,
  credentials: true
}));
app.use(express.json());
app.use(morgan('dev'));

app.use((req, res, next) => {
  res.on('finish', () => {
    if (res.statusCode === 404) {
      fs.appendFileSync(path.join(__dirname, '../../stream-debug.log'), `[${new Date().toISOString()}] 404 NOT FOUND: ${req.method} ${req.originalUrl}\n`);
    }
  });
  next();
});


// Ensure data directories exist
const dataDir = process.env.DATA_DIR || path.join(__dirname, '../../data');
const uploadsDir = path.join(dataDir, 'uploads');
const thumbnailsDir = path.join(dataDir, 'thumbnails');
const trashDir = path.join(dataDir, '.trash');

[uploadsDir, thumbnailsDir, trashDir].forEach((dir) => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
});

import { initDb } from './db/index';
initDb();

import cookieParser from 'cookie-parser';
app.use(cookieParser());

import authRoutes from './routes/auth';
app.use('/api/auth', authRoutes);

import apiRoutes from './routes/api';
import { errorHandler } from './middleware/error-handler';

app.use('/api', apiRoutes);

app.get('/api/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

app.use(errorHandler);

app.listen(port as number, host, () => {
  console.log(`Server listening on http://${host}:${port}`);
});
