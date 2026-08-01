import { Router } from 'express';
import { upload } from '../middleware/upload';
import { videoRepo, tagRepo, stateRepo, categoryRepo, userRepo } from '../db/repository';
import { inspectVideo, generateThumbnail, cleanupFailedProcessing } from '../services/media-processor';
import { AppError } from '../middleware/error-handler';
import path from 'path';
import fs from 'fs';
import fsPromises from 'fs/promises';
import { v4 as uuidv4 } from 'uuid';
import { authenticate, authorizeRoles } from '../middleware/auth';
import * as argon2 from 'argon2';

const router = Router();
const dataDir = process.env.DATA_DIR || path.join(__dirname, '../../../data');
const thumbnailsDir = path.join(dataDir, 'thumbnails');
const trashDir = path.join(dataDir, '.trash');

// Apply authentication to all /api routes except what's handled before (like /api/auth)
router.use(authenticate);

// Admin only middleware
const requireAdmin = authorizeRoles('admin');

router.get('/summary', requireAdmin, (req, res) => {
  const summary = videoRepo.getSummary();
  res.json(summary);
});

router.get('/videos', (req, res) => {
  const categoryId = req.query.categoryId as string | undefined;
  const tagId = req.query.tagId as string | undefined;
  const includeUncategorized = req.query.includeUncategorized === 'true';

  let videos;
  if (req.user?.role === 'admin') {
    // Admin can see all active videos maybe including uncategorized?
    videos = videoRepo.listReadyWithDetails(categoryId, tagId, includeUncategorized);
  } else {
    if (categoryId) {
      const category = categoryRepo.getById(categoryId);
      if (!category || category.is_active === 0) {
        return res.json({ videos: [] });
      }
      videos = videoRepo.listReadyWithDetails(categoryId, tagId, false);
    } else {
      videos = videoRepo.listReadyWithDetails(categoryId, tagId, false);
      const activeCategories = categoryRepo.listAll(false);
      const activeTags = new Set<string>();
      activeCategories.forEach(c => {
         const catTags = categoryRepo.getTags(c.id);
         catTags.forEach(t => activeTags.add(t.id));
      });
      videos = videos.filter(v => v.tags.some((t: any) => activeTags.has(t.id)));
    }
  }
  
  const manifest = videos.map(v => ({
    id: v.id,
    title: v.title,
    originalFilename: v.original_filename,
    durationSeconds: v.duration_seconds,
    width: v.width,
    height: v.height,
    codec: v.codec,
    audioCodec: v.audio_codec,
    sizeBytes: v.size_bytes,
    thumbnailUrl: `/api/videos/${v.id}/thumbnail`,
    streamUrl: `/api/videos/${v.id}/stream`,
    category: v.category,
    tags: v.tags,
    updatedAt: v.updated_at
  }));

  if (req.user?.role !== 'admin') {
    for (let i = manifest.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [manifest[i], manifest[j]] = [manifest[j], manifest[i]];
    }
  }

  res.json({ videos: manifest });
});

router.post('/upload', requireAdmin, upload.single('video'), async (req, res, next) => {
  if (!req.file) {
    return next(new AppError('MISSING_FILE', 'No video file provided'));
  }

  // categoryId is no longer used, videos are categorized by tags
  const categoryId = undefined;

  const id = uuidv4();
  const storageKey = req.file.filename;
  const videoPath = req.file.path;
  const thumbnailFilename = `${id}.jpg`;
  const thumbnailPath = path.join(thumbnailsDir, thumbnailFilename);

  try {
    const metadata = await inspectVideo(videoPath);
    
    // V1 Compatibility check
    if (metadata.containerFormat !== 'mov,mp4,m4a,3gp,3g2,mj2' && !metadata.containerFormat.includes('mp4')) {
       throw new AppError('UNSUPPORTED_FORMAT', 'Only MP4 containers are fully supported in v1');
    }
    if (metadata.codec !== 'h264') {
       throw new AppError('UNSUPPORTED_CODEC', 'Only H.264 video codec is supported in v1');
    }
    
    await generateThumbnail(videoPath, thumbnailPath);

    const now = new Date().toISOString();
    videoRepo.create({
      id,
      title: req.body.title || req.file.originalname,
      original_filename: req.file.originalname,
      storage_key: storageKey,
      mime_type: req.file.mimetype,
      size_bytes: req.file.size,
      duration_seconds: metadata.durationSeconds,
      width: metadata.width,
      height: metadata.height,
      codec: metadata.codec,
      audio_codec: metadata.audioCodec,
      thumbnail_path: thumbnailFilename,
      processing_status: 'ready',
      category_id: categoryId,
      created_at: now,
      updated_at: now
    });

    // Handle tags if provided
    if (req.body.tags) {
      try {
        const parsedTags = JSON.parse(req.body.tags);
        if (Array.isArray(parsedTags)) {
          for (const tagId of parsedTags) {
            tagRepo.attachToVideo(id, tagId);
          }
        }
      } catch (e) {
        // Ignored
      }
    }

    const videos = videoRepo.listReadyWithDetails();
    const v = videos.find(vid => vid.id === id);
    if (!v) throw new Error('Failed to retrieve created video');

    res.status(201).json({
      video: {
        id: v.id,
        title: v.title,
        originalFilename: v.original_filename,
        durationSeconds: v.duration_seconds,
        width: v.width,
        height: v.height,
        codec: v.codec,
        audioCodec: v.audio_codec,
        sizeBytes: v.size_bytes,
        thumbnailUrl: `/api/videos/${v.id}/thumbnail`,
        streamUrl: `/api/videos/${v.id}/stream`,
        category: v.category,
        tags: v.tags,
        updatedAt: v.updated_at
      }
    });
  } catch (err) {
    await cleanupFailedProcessing(videoPath, thumbnailPath);
    next(err);
  }
});

router.get('/videos/:id/thumbnail', (req, res, next) => {
  const video = videoRepo.getById(req.params.id);
  if (!video || !video.thumbnail_path) {
    return next(new AppError('NOT_FOUND', 'Thumbnail not found', 404));
  }
  const tPath = path.join(thumbnailsDir, video.thumbnail_path);
  if (!fs.existsSync(tPath)) {
    return next(new AppError('NOT_FOUND', 'Thumbnail file missing', 404));
  }
  res.sendFile(tPath);
});

router.get('/videos/:id/stream', (req, res, next) => {
  const video = videoRepo.getById(req.params.id);
  if (!video) {
    return next(new AppError('NOT_FOUND', 'Video not found', 404));
  }

  const vPath = path.join(dataDir, 'uploads', video.storage_key);
  if (!fs.existsSync(vPath)) {
    return next(new AppError('NOT_FOUND', 'Video file missing', 404));
  }

  const stat = fs.statSync(vPath);
  const fileSize = stat.size;
  const range = req.headers.range;

  if (range) {
    const parts = range.replace(/bytes=/, "").split("-");
    const start = parseInt(parts[0], 10);
    const end = parts[1] ? parseInt(parts[1], 10) : fileSize - 1;

    if (start >= fileSize) {
      res.status(416).send('Requested range not satisfiable\\n' + start + ' >= ' + fileSize);
      return;
    }

    const chunksize = (end - start) + 1;
    const file = fs.createReadStream(vPath, { start, end });
    const head = {
      'Content-Range': `bytes ${start}-${end}/${fileSize}`,
      'Accept-Ranges': 'bytes',
      'Content-Length': chunksize,
      'Content-Type': video.mime_type || 'video/mp4',
    };

    res.writeHead(206, head);
    file.pipe(res);
  } else {
    const head = {
      'Content-Length': fileSize,
      'Content-Type': video.mime_type || 'video/mp4',
    };
    res.writeHead(200, head);
    fs.createReadStream(vPath).pipe(res);
  }
});

router.delete('/videos/:id', requireAdmin, async (req, res, next) => {
  const videoId = req.params.id;
  const video = videoRepo.getById(videoId);

  if (!video) {
    return res.status(404).json({
      error: { code: 'VIDEO_NOT_FOUND', message: 'Video was not found.' }
    });
  }

  const now = new Date().toISOString();
  try {
    videoRepo.softDelete(videoId, now);
  } catch (err) {
    return next(new AppError('DB_ERROR', 'Failed to delete video record'));
  }

  const vPath = path.join(dataDir, 'uploads', video.storage_key);
  const tPath = video.thumbnail_path ? path.join(thumbnailsDir, video.thumbnail_path) : null;
  const videoTrashDir = path.join(trashDir, videoId);

  setImmediate(async () => {
    try {
      await fsPromises.mkdir(videoTrashDir, { recursive: true });
      if (fs.existsSync(vPath)) {
        await fsPromises.rename(vPath, path.join(videoTrashDir, video.storage_key));
      }
      if (tPath && fs.existsSync(tPath)) {
        await fsPromises.rename(tPath, path.join(videoTrashDir, video.thumbnail_path!));
      }
      videoRepo.hardDelete(videoId);
      await fsPromises.rm(videoTrashDir, { recursive: true, force: true });
    } catch (e) {
      console.error(`Failed to move video ${videoId} to trash`, e);
    }
  });

  res.status(204).send();
});

// Categories
router.get('/categories', (req, res) => {
  const includeInactive = req.user?.role === 'admin' && req.query.includeInactive === 'true';
  const categories = categoryRepo.listAll(includeInactive).map(c => ({
    ...c,
    tags: categoryRepo.getTags(c.id)
  }));
  res.json(categories);
});

router.post('/categories', requireAdmin, (req, res, next) => {
  const { name, slug, color, icon, sort_order, is_active } = req.body;
  if (!name || !slug || !color) return next(new AppError('INVALID_INPUT', 'Name, slug, and color required'));
  
  const id = uuidv4();
  const now = new Date().toISOString();
  try {
    categoryRepo.create({
      id, name, slug, color, icon, 
      sort_order: sort_order || 0, 
      is_active: is_active === undefined ? 1 : is_active, 
      created_at: now, updated_at: now
    });
    res.status(201).json(categoryRepo.getById(id));
  } catch (err: any) {
    if (err.message.includes('UNIQUE constraint failed')) {
      return next(new AppError('DUPLICATE', 'Category name or slug already exists', 400));
    }
    next(err);
  }
});

router.patch('/categories/:id', requireAdmin, (req, res, next) => {
  const { name, slug, color, icon, sort_order, is_active } = req.body;
  const now = new Date().toISOString();
  try {
    categoryRepo.update(req.params.id, {
      ...(name !== undefined && { name }),
      ...(slug !== undefined && { slug }),
      ...(color !== undefined && { color }),
      ...(icon !== undefined && { icon }),
      ...(sort_order !== undefined && { sort_order }),
      ...(is_active !== undefined && { is_active }),
      updated_at: now
    });
    res.json(categoryRepo.getById(req.params.id));
  } catch (err) {
    next(err);
  }
});

router.delete('/categories/:id', requireAdmin, (req, res, next) => {
  try {
    const videos = videoRepo.listReadyWithDetails(req.params.id, undefined, false);
    if (videos.length > 0) {
      return next(new AppError('CATEGORY_HAS_VIDEOS', 'Cannot delete category with assigned videos', 400));
    }
    categoryRepo.delete(req.params.id);
    res.status(204).send();
  } catch (err) {
    next(err);
  }
});

// Category Tags
router.post('/categories/:id/tags', requireAdmin, (req, res, next) => {
  const { tagId } = req.body;
  if (!tagId) return next(new AppError('INVALID_INPUT', 'TagId required'));
  try {
    categoryRepo.assignTag(req.params.id, tagId);
    res.status(204).send();
  } catch (err) {
    next(err);
  }
});

router.delete('/categories/:id/tags/:tagId', requireAdmin, (req, res, next) => {
  try {
    categoryRepo.removeTag(req.params.id, req.params.tagId);
    res.status(204).send();
  } catch (err) {
    next(err);
  }
});

// Tags
router.get('/tags', requireAdmin, (req, res) => {
  res.json(tagRepo.listAll());
});

router.post('/tags', requireAdmin, (req, res, next) => {
  const { name, color } = req.body;
  if (!name || !color) return next(new AppError('INVALID_INPUT', 'Name and color required'));
  
  const id = uuidv4();
  const now = new Date().toISOString();
  try {
    tagRepo.create({ id, name, color, created_at: now });
    res.status(201).json({ id, name, color, created_at: now });
  } catch (err: any) {
    if (err.message.includes('UNIQUE constraint failed')) {
      return next(new AppError('DUPLICATE', 'Tag name already exists', 400));
    }
    next(err);
  }
});

router.patch('/tags/:id', requireAdmin, (req, res, next) => {
  const { name, color } = req.body;
  try {
    tagRepo.update(req.params.id, {
      ...(name !== undefined && { name }),
      ...(color !== undefined && { color })
    });
    res.json(tagRepo.listAll().find(t => t.id === req.params.id));
  } catch (err) {
    next(err);
  }
});

router.delete('/tags/:id', requireAdmin, (req, res, next) => {
  try {
    tagRepo.delete(req.params.id);
    res.status(204).send();
  } catch (err) {
    next(err);
  }
});

// Video Tags
router.post('/videos/:id/tags', requireAdmin, (req, res, next) => {
  const { tagId } = req.body;
  if (!tagId) return next(new AppError('INVALID_INPUT', 'TagId required'));
  
  try {
    const video = videoRepo.listReadyWithDetails().find(v => v.id === req.params.id);
    if (!video) return next(new AppError('NOT_FOUND', 'Video not found', 404));

    tagRepo.attachToVideo(req.params.id, tagId);
    res.status(204).send();
  } catch (err) {
    next(err);
  }
});

router.delete('/videos/:id/tags/:tagId', requireAdmin, (req, res, next) => {
  try {
    tagRepo.detachFromVideo(req.params.id, req.params.tagId);
    res.status(204).send();
  } catch (err) {
    next(err);
  }
});

// State
router.get('/videos/:id/state', (req, res) => {
  const userId = req.user!.id;
  const state = stateRepo.getState(userId, req.params.id);
  res.json(state || { user_id: userId, video_id: req.params.id, liked: 0, note: '', progress_seconds: 0 });
});

router.put('/videos/:id/state', (req, res, next) => {
  const { liked, note, progress_seconds } = req.body;
  const userId = req.user!.id;
  try {
    stateRepo.upsertState({
      user_id: userId,
      video_id: req.params.id,
      liked: liked ? 1 : 0,
      note: note || '',
      progress_seconds: progress_seconds || 0,
      updated_at: new Date().toISOString()
    });
    res.status(200).json({ success: true });
  } catch (err) {
    next(err);
  }
});

// Users
router.get('/users', requireAdmin, (req, res) => {
  res.json(userRepo.listAll());
});

router.patch('/users/:id/status', requireAdmin, (req, res, next) => {
  const { is_active } = req.body;
  if (typeof is_active !== 'number') {
    return next(new AppError('INVALID_INPUT', 'is_active must be a number (0 or 1)'));
  }
  
  if (req.user?.id === req.params.id) {
    return next(new AppError('FORBIDDEN', 'Cannot change your own status', 403));
  }

  try {
    userRepo.updateStatus(req.params.id, is_active);
    res.status(200).json({ success: true });
  } catch (err) {
    next(err);
  }
});

router.delete('/users/:id', requireAdmin, (req, res, next) => {
  if (req.user?.id === req.params.id) {
    return next(new AppError('FORBIDDEN', 'Cannot delete yourself', 403));
  }
  try {
    userRepo.delete(req.params.id);
    res.status(204).send();
  } catch (err) {
    next(err);
  }
});

router.patch('/users/:id/password', requireAdmin, async (req, res, next) => {
  const { password } = req.body;
  if (!password || typeof password !== 'string' || password.length < 6) {
    return next(new AppError('INVALID_INPUT', 'Password must be at least 6 characters'));
  }
  
  try {
    const passwordHash = await argon2.hash(password);
    userRepo.updatePassword(req.params.id, passwordHash);
    res.status(200).json({ success: true });
  } catch (err) {
    next(err);
  }
});

export default router;
