import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MediaApiService } from '../services/media-api.service';

import { HlmCardImports } from '@spartan-ng/helm/card';
import { HlmIconImports } from '@spartan-ng/helm/icon';
import { HlmTableImports } from '@spartan-ng/helm/table';
import { HlmButtonImports } from '@spartan-ng/helm/button';
import { HlmSpinnerImports } from '@spartan-ng/helm/spinner';
import { MetricCardComponent } from '../shared/components/metric-card.component';

import { provideIcons } from '@ng-icons/core';
import { lucideActivity, lucideVideo, lucideUsers, lucideHeart, lucideClock, lucideHardDrive, lucideRefreshCw } from '@ng-icons/lucide';

export interface TopVideo {
  id: string;
  title: string;
  original_filename: string;
  total_watch_time?: number;
  likes?: number;
}

export interface Summary {
  totalVideos: number;
  totalSizeBytes: number;
  totalTags: number;
  totalLikes: number;
  totalWatchTime: number;
  totalUsers: number;
  topWatched: TopVideo[];
  topLiked: TopVideo[];
}

@Component({
  selector: 'app-analytics-page',
  standalone: true,
  imports: [
    CommonModule,
    HlmCardImports,
    HlmIconImports,
    HlmTableImports,
    HlmButtonImports,
    HlmSpinnerImports,
    MetricCardComponent
  ],
  providers: [
    provideIcons({ lucideActivity, lucideVideo, lucideUsers, lucideHeart, lucideClock, lucideHardDrive, lucideRefreshCw })
  ],
  templateUrl: './analytics.page.html'
})
export class AnalyticsPage implements OnInit {
  private api = inject(MediaApiService);

  summary: Summary | null = null;
  isLoading = true;

  ngOnInit() {
    this.loadData();
  }

  loadData() {
    this.isLoading = true;
    this.api.getSummary().subscribe({
      next: (s) => {
        this.summary = s;
        this.isLoading = false;
      },
      error: () => {
        this.isLoading = false;
      }
    });
  }

  formatBytes(bytes: number) {
    if (!bytes || bytes === 0) return '0 B';
    const k = 1024, dm = 2, sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
  }

  formatDuration(seconds: number) {
    if (!seconds) return '0:00';
    const h = Math.floor(seconds / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    const s = Math.floor(seconds % 60);
    
    if (h > 0) {
      return `${h}h ${m}m ${s}s`;
    }
    return `${m}m ${s}s`;
  }
}
