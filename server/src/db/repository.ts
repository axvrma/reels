import db from './index';

export interface UserRecord {
  id: string;
  email: string;
  role: string;
  is_active: number;
  created_at: string;
  updated_at: string;
  last_login_at: string;
}

export interface CategoryRecord {
  id: string;
  name: string;
  slug: string;
  color: string;
  icon?: string;
  sort_order: number;
  is_active: number;
  created_at: string;
  updated_at: string;
}

export interface VideoRecord {
  id: string;
  title: string;
  original_filename: string;
  storage_key: string;
  mime_type?: string;
  size_bytes: number;
  duration_seconds?: number;
  width?: number;
  height?: number;
  codec?: string;
  audio_codec?: string;
  thumbnail_path?: string;
  processing_status: string;
  processing_error?: string;
  category_id?: string;
  created_at: string;
  updated_at: string;
  deleted_at?: string;
}

export interface TagRecord {
  id: string;
  name: string;
  color: string;
  created_at: string;
}

export interface VideoStateRecord {
  user_id: string;
  video_id: string;
  liked: number;
  note: string;
  progress_seconds: number;
  updated_at: string;
}

export const categoryRepo = {
  create: (cat: Partial<CategoryRecord>) => {
    const stmt = db.prepare(`
      INSERT INTO categories (id, name, slug, color, icon, sort_order, is_active, created_at, updated_at)
      VALUES (@id, @name, @slug, @color, @icon, @sort_order, @is_active, @created_at, @updated_at)
    `);
    return stmt.run(cat);
  },
  
  update: (id: string, cat: Partial<CategoryRecord>) => {
    const fields = Object.keys(cat).map(k => `${k} = @${k}`).join(', ');
    const stmt = db.prepare(`UPDATE categories SET ${fields} WHERE id = @id`);
    return stmt.run({ ...cat, id });
  },

  delete: (id: string) => {
    return db.prepare('DELETE FROM categories WHERE id = ?').run(id);
  },

  getById: (id: string) => {
    return db.prepare('SELECT * FROM categories WHERE id = ?').get(id) as CategoryRecord | undefined;
  },

  listAll: (includeInactive = false) => {
    if (includeInactive) {
      return db.prepare('SELECT * FROM categories ORDER BY sort_order ASC, name ASC').all() as CategoryRecord[];
    }
    return db.prepare('SELECT * FROM categories WHERE is_active = 1 ORDER BY sort_order ASC, name ASC').all() as CategoryRecord[];
  },

  assignTag: (categoryId: string, tagId: string) => {
    return db.prepare('INSERT OR IGNORE INTO category_tags (category_id, tag_id) VALUES (?, ?)').run(categoryId, tagId);
  },

  removeTag: (categoryId: string, tagId: string) => {
    return db.prepare('DELETE FROM category_tags WHERE category_id = ? AND tag_id = ?').run(categoryId, tagId);
  },

  getTags: (categoryId: string) => {
    return db.prepare(`
      SELECT t.* FROM tags t
      JOIN category_tags ct ON t.id = ct.tag_id
      WHERE ct.category_id = ?
    `).all(categoryId) as TagRecord[];
  }
};

export const videoRepo = {
  create: (video: Partial<VideoRecord>) => {
    const stmt = db.prepare(`
      INSERT INTO videos (
        id, title, original_filename, storage_key, mime_type, 
        size_bytes, duration_seconds, width, height, codec, 
        audio_codec, thumbnail_path, processing_status, 
        processing_error, category_id, created_at, updated_at
      ) VALUES (
        @id, @title, @original_filename, @storage_key, @mime_type, 
        @size_bytes, @duration_seconds, @width, @height, @codec, 
        @audio_codec, @thumbnail_path, @processing_status, 
        @processing_error, @category_id, @created_at, @updated_at
      )
    `);
    return stmt.run({
      id: video.id ?? null,
      title: video.title ?? null,
      original_filename: video.original_filename ?? null,
      storage_key: video.storage_key ?? null,
      mime_type: video.mime_type ?? null,
      size_bytes: video.size_bytes ?? 0,
      duration_seconds: video.duration_seconds ?? null,
      width: video.width ?? null,
      height: video.height ?? null,
      codec: video.codec ?? null,
      audio_codec: video.audio_codec ?? null,
      thumbnail_path: video.thumbnail_path ?? null,
      processing_status: video.processing_status ?? 'ready',
      processing_error: video.processing_error ?? null,
      category_id: video.category_id ?? null,
      created_at: video.created_at ?? null,
      updated_at: video.updated_at ?? null
    });
  },

  updateCategory: (videoId: string, categoryId: string | null) => {
    return db.prepare('UPDATE videos SET category_id = ?, updated_at = datetime("now") WHERE id = ?').run(categoryId, videoId);
  },

  getById: (id: string) => {
    return db.prepare('SELECT * FROM videos WHERE id = ? AND deleted_at IS NULL').get(id) as VideoRecord | undefined;
  },

  listReadyWithDetails: (categoryId?: string, tagId?: string, includeUncategorized?: boolean) => {
    let query = "SELECT * FROM videos WHERE processing_status = 'ready' AND deleted_at IS NULL";
    const params: any[] = [];

    if (categoryId) {
      query += ` AND id IN (
        SELECT vt.video_id FROM video_tags vt
        JOIN category_tags ct ON vt.tag_id = ct.tag_id
        WHERE ct.category_id = ?
      )`;
      params.push(categoryId);
    } else if (includeUncategorized) {
      query += ' AND id NOT IN (SELECT video_id FROM video_tags)';
    }

    if (tagId) {
      query += ' AND id IN (SELECT video_id FROM video_tags WHERE tag_id = ?)';
      params.push(tagId);
    }

    query += ' ORDER BY created_at DESC';
    const videos = db.prepare(query).all(...params) as VideoRecord[];
    return _attachDetailsToVideos(videos);
  },

  listAllWithDetails: () => {
    const videos = db.prepare('SELECT * FROM videos WHERE deleted_at IS NULL ORDER BY created_at DESC').all() as VideoRecord[];
    return _attachDetailsToVideos(videos);
  },

  softDelete: (id: string, timestamp: string) => {
    return db.prepare('UPDATE videos SET deleted_at = ? WHERE id = ?').run(timestamp, id);
  },

  hardDelete: (id: string) => {
    return db.prepare('DELETE FROM videos WHERE id = ?').run(id);
  },

  getSummary: () => {
    const totalVideosRow = db.prepare('SELECT COUNT(*) as c, SUM(size_bytes) as s FROM videos WHERE deleted_at IS NULL').get() as { c: number, s: number };
    const totalTagsRow = db.prepare('SELECT COUNT(*) as c FROM tags').get() as { c: number };
    const statsRow = db.prepare('SELECT SUM(liked) as totalLikes, SUM(progress_seconds) as totalWatchTime FROM user_video_state').get() as { totalLikes: number, totalWatchTime: number };
    const totalUsersRow = db.prepare('SELECT COUNT(*) as c FROM users WHERE is_active = 1').get() as { c: number };
    
    const topWatched = db.prepare('SELECT v.id, v.title, v.original_filename, SUM(s.progress_seconds) as total_watch_time FROM videos v JOIN user_video_state s ON v.id = s.video_id WHERE v.deleted_at IS NULL GROUP BY v.id ORDER BY total_watch_time DESC LIMIT 5').all();
    const topLiked = db.prepare('SELECT v.id, v.title, v.original_filename, SUM(s.liked) as likes FROM videos v JOIN user_video_state s ON v.id = s.video_id WHERE v.deleted_at IS NULL GROUP BY v.id ORDER BY likes DESC LIMIT 5').all();

    return {
      totalVideos: totalVideosRow.c,
      totalSizeBytes: totalVideosRow.s || 0,
      totalTags: totalTagsRow.c,
      totalLikes: statsRow.totalLikes || 0,
      totalWatchTime: statsRow.totalWatchTime || 0,
      totalUsers: totalUsersRow.c,
      topWatched,
      topLiked
    };
  }
};

export const tagRepo = {
  create: (tag: TagRecord) => {
    const stmt = db.prepare(`
      INSERT INTO tags (id, name, color, created_at)
      VALUES (@id, @name, @color, @created_at)
    `);
    return stmt.run(tag);
  },

  update: (id: string, tag: Partial<TagRecord>) => {
    const fields = Object.keys(tag).map(k => `${k} = @${k}`).join(', ');
    const stmt = db.prepare(`UPDATE tags SET ${fields} WHERE id = @id`);
    return stmt.run({ ...tag, id });
  },

  delete: (id: string) => {
    return db.prepare('DELETE FROM tags WHERE id = ?').run(id);
  },

  listAll: () => {
    return db.prepare('SELECT * FROM tags ORDER BY name ASC').all() as TagRecord[];
  },

  attachToVideo: (videoId: string, tagId: string) => {
    const stmt = db.prepare(`
      INSERT OR IGNORE INTO video_tags (video_id, tag_id)
      VALUES (?, ?)
    `);
    return stmt.run(videoId, tagId);
  },

  detachFromVideo: (videoId: string, tagId: string) => {
    const stmt = db.prepare(`
      DELETE FROM video_tags WHERE video_id = ? AND tag_id = ?
    `);
    return stmt.run(videoId, tagId);
  }
};

export const stateRepo = {
  getState: (userId: string, videoId: string) => {
    return db.prepare('SELECT * FROM user_video_state WHERE user_id = ? AND video_id = ?').get(userId, videoId) as VideoStateRecord | undefined;
  },

  upsertState: (state: VideoStateRecord) => {
    const stmt = db.prepare(`
      INSERT INTO user_video_state (user_id, video_id, liked, note, progress_seconds, updated_at)
      VALUES (@user_id, @video_id, @liked, @note, @progress_seconds, @updated_at)
      ON CONFLICT(user_id, video_id) DO UPDATE SET
        liked = excluded.liked,
        note = excluded.note,
        progress_seconds = excluded.progress_seconds,
        updated_at = excluded.updated_at
    `);
    return stmt.run(state);
  }
};

export const userRepo = {
  listAll: () => {
    return db.prepare('SELECT id, email, role, is_active, created_at, updated_at, last_login_at FROM users ORDER BY created_at DESC').all() as UserRecord[];
  },

  updateStatus: (id: string, is_active: number) => {
    db.prepare("UPDATE users SET is_active = ?, updated_at = datetime('now') WHERE id = ?").run(is_active, id);
    if (is_active === 0) {
      db.prepare("UPDATE refresh_tokens SET revoked_at = datetime('now') WHERE user_id = ? AND revoked_at IS NULL").run(id);
    }
  },

  delete: (id: string) => {
    db.prepare('DELETE FROM refresh_tokens WHERE user_id = ?').run(id);
    db.prepare('DELETE FROM user_video_state WHERE user_id = ?').run(id);
    return db.prepare('DELETE FROM users WHERE id = ?').run(id);
  },

  updatePassword: (id: string, password_hash: string) => {
    db.prepare("UPDATE users SET password_hash = ?, updated_at = datetime('now') WHERE id = ?").run(password_hash, id);
    db.prepare("UPDATE refresh_tokens SET revoked_at = datetime('now') WHERE user_id = ? AND revoked_at IS NULL").run(id);
  }
};

function _attachDetailsToVideos(videos: VideoRecord[]) {
  if (videos.length === 0) return [];

  const categoryIds = Array.from(new Set(videos.map(v => v.category_id).filter(Boolean)));
  const categories = categoryIds.length > 0 
    ? db.prepare(`SELECT * FROM categories WHERE id IN (${categoryIds.map(() => '?').join(',')})`).all(...categoryIds) as CategoryRecord[]
    : [];

  const tagStmt = db.prepare(`
    SELECT t.*, vt.video_id 
    FROM tags t 
    JOIN video_tags vt ON t.id = vt.tag_id 
    WHERE vt.video_id IN (${videos.map(() => '?').join(',')})
  `);
  const tags = tagStmt.all(...videos.map(v => v.id)) as (TagRecord & { video_id: string })[];
  
  const catTags = db.prepare('SELECT * FROM category_tags').all() as {category_id: string, tag_id: string}[];
  const allCategories = db.prepare('SELECT * FROM categories').all() as CategoryRecord[];

  return videos.map(video => {
    const videoTags = tags.filter(t => t.video_id === video.id).map(t => {
      const { video_id, ...rest } = t;
      return rest;
    });
    let category = categories.find(c => c.id === video.category_id) || null;
    
    if (!category) {
      for (const tag of videoTags) {
        const ct = catTags.find(ct => ct.tag_id === tag.id);
        if (ct) {
          category = allCategories.find(c => c.id === ct.category_id) || null;
          if (category) break;
        }
      }
    }

    return { ...video, tags: videoTags, category };
  });
}
