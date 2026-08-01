import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { forkJoin, Observable } from 'rxjs';
import { MediaApiService } from '../services/media-api.service';

import { HlmCardImports } from '@spartan-ng/helm/card';
import { HlmButtonImports } from '@spartan-ng/helm/button';
import { HlmIconImports } from '@spartan-ng/helm/icon';
import { HlmTableImports } from '@spartan-ng/helm/table';
import { HlmInputImports } from '@spartan-ng/helm/input';
import { HlmLabelImports } from '@spartan-ng/helm/label';
import { HlmBadgeImports } from '@spartan-ng/helm/badge';
import { HlmDropdownMenuImports } from '@spartan-ng/helm/dropdown-menu';


import { HlmDialogService } from '../components/ui/dialog/src/lib/hlm-dialog.service';

import { MetricCardComponent } from '../shared/components/metric-card.component';
import { UploadDialogComponent } from '../shared/components/upload-dialog.component';
import { VideoPlayerDialogComponent } from '../shared/components/video-player-dialog.component';
import { UpdateTagsDialogComponent } from '../shared/components/update-tags-dialog.component';

import { AuthService } from '../services/auth.service';

import { provideIcons } from '@ng-icons/core';
import { lucideUpload, lucideVideo, lucideDatabase, lucideFolder, lucideTag, lucideCirclePlay, lucideEllipsisVertical, lucideTrash, lucideSearch } from '@ng-icons/lucide';

export interface Video {
  id: string;
  title: string;
  originalFilename: string;
  durationSeconds: number;
  sizeBytes: number;
  category?: { id: string; name: string; color: string; };
  tags: any[];
  thumbnailUrl: string;
}

@Component({
  selector: 'app-dashboard-page',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule,
    ReactiveFormsModule,
    HlmCardImports,
    HlmButtonImports,
    HlmIconImports,
    HlmTableImports,
    HlmInputImports,
    HlmLabelImports,
    HlmBadgeImports,
    HlmDropdownMenuImports,
    
    MetricCardComponent
  ],
  providers: [
    provideIcons({ lucideUpload, lucideVideo, lucideDatabase, lucideFolder, lucideTag, lucideCirclePlay, lucideEllipsisVertical, lucideTrash, lucideSearch })
  ],
  templateUrl: './dashboard.page.html'
})
export class DashboardPage implements OnInit {
  private api = inject(MediaApiService);
  private auth = inject(AuthService);
  private dialogService = inject(HlmDialogService);
  private cdr = inject(ChangeDetectorRef);
  
  summary: any;
  videos: Video[] = [];
  filteredVideos: Video[] = [];
  categories: any[] = [];
  availableTags: any[] = [];
  isLoading = true;
  
  searchQuery = '';
  selectedCategoryFilter = 'all';
  selectedVideos: Set<string> = new Set();

  ngOnInit() {
    this.loadData();
  }

  loadData() {
    this.isLoading = true;
    forkJoin({
      summary: this.api.getSummary(),
      tags: this.api.getTags(),
      categories: this.api.getCategories(true)
    }).subscribe({
      next: (res) => {
        this.summary = res.summary;
        this.availableTags = res.tags;
        this.categories = res.categories;
        this.loadVideos();
      },
      error: (err) => {
        console.error('Error loading initial data', err);
        this.isLoading = false;
        this.cdr.detectChanges();
      }
    });
  }

  loadVideos() {
    this.api.getVideos().subscribe({
      next: (res) => {
        this.videos = res.videos;
        this.applyFilters();
        this.isLoading = false;
        this.cdr.detectChanges();
      },
      error: (err) => {
        console.error('Error loading videos', err);
        this.isLoading = false;
        this.cdr.detectChanges();
      }
    });
  }

  applyFilters() {
    let filtered = this.videos;

    // Filter by search query
    if (this.searchQuery.trim()) {
      const q = this.searchQuery.toLowerCase().trim();
      filtered = filtered.filter(v => 
        (v.title && v.title.toLowerCase().includes(q)) ||
        (v.originalFilename && v.originalFilename.toLowerCase().includes(q)) ||
        (v.tags && v.tags.some((t: any) => t.name.toLowerCase().includes(q)))
      );
    }

    // Filter by category
    if (this.selectedCategoryFilter === 'all') {
      this.filteredVideos = filtered;
    } else if (this.selectedCategoryFilter === 'uncategorized') {
      this.filteredVideos = filtered.filter(v => !v.category);
    } else {
      this.filteredVideos = filtered.filter(v => v.category?.id === this.selectedCategoryFilter);
    }
  }

  onFilterChange(event: Event) {
    const value = (event.target as HTMLSelectElement).value;
    this.selectedCategoryFilter = value;
    this.applyFilters();
  }

  onSearchChange(event: Event) {
    const value = (event.target as HTMLInputElement).value;
    this.searchQuery = value;
    this.applyFilters();
  }

  toggleSelectAll(event: any) {
    if (event.target.checked) {
      this.selectedVideos = new Set(this.filteredVideos.map(v => v.id));
    } else {
      this.selectedVideos = new Set();
    }
    this.cdr.detectChanges();
  }

  toggleVideoSelection(videoId: string) {
    const newSet = new Set(this.selectedVideos);
    if (newSet.has(videoId)) {
      newSet.delete(videoId);
    } else {
      newSet.add(videoId);
    }
    this.selectedVideos = newSet;
    this.cdr.detectChanges();
  }

  isAllSelected(): boolean {
    return this.filteredVideos.length > 0 && this.selectedVideos.size === this.filteredVideos.length;
  }

  getTopTags(video: Video): any[] {
    return (video.tags || []).slice(0, 2);
  }

  getThumbnailUrl(url: string | undefined): string {
    if (!url) return 'assets/placeholder.png';
    const token = this.auth.token;
    if (token) {
      return `${url}?token=${token}`;
    }
    return url;
  }

  playVideo(video: Video) {
    let streamUrl = `/api/videos/${video.id}/stream`;
    if (this.auth.token) {
      streamUrl += `?token=${this.auth.token}`;
    }
    
    this.dialogService.open(VideoPlayerDialogComponent, {
      context: { title: video.title || video.originalFilename, streamUrl },
      contentClass: 'sm:max-w-[900px] w-full p-0 overflow-hidden bg-black border-0'
    });
  }

  openUploadDialog() {
    const dialogRef = this.dialogService.open(UploadDialogComponent, {
      context: { availableTags: this.availableTags },
      contentClass: 'sm:max-w-lg'
    });

    dialogRef.closed$.subscribe(result => {
      if (result) {
        this.loadData();
      }
    });
  }

  deleteVideo(video: any) {
    if(confirm(`Are you sure you want to delete "${video.title || video.originalFilename}"?`)) {
      this.api.deleteVideo(video.id).subscribe({
        next: () => {
          this.loadData();
        },
        error: () => {
          alert('Delete failed.');
        }
      });
    }
  }

  updateTags(video: Video) {
    const dialogRef = this.dialogService.open(UpdateTagsDialogComponent, {
      context: {
        videoId: video.id,
        currentTags: video.tags,
        availableTags: this.availableTags
      },
      contentClass: 'sm:max-w-sm'
    });

    dialogRef.closed$.subscribe(selectedTags => {
      if (!selectedTags) return; // User cancelled
      
      const currentTagIds = (video.tags || []).map(t => t.id);
      const newTagIds = selectedTags as string[];
      
      const tagsToAdd = newTagIds.filter(id => !currentTagIds.includes(id));
      const tagsToRemove = currentTagIds.filter(id => !newTagIds.includes(id));
      
      const requests: Observable<any>[] = [];
      
      tagsToAdd.forEach(id => {
        requests.push(this.api.attachTag(video.id, id));
      });
      
      tagsToRemove.forEach(id => {
        requests.push(this.api.detachTag(video.id, id));
      });
      
      if (requests.length > 0) {
        forkJoin(requests).subscribe({
          next: () => {
            this.loadVideos();
          },
          error: () => {
            alert('Failed to update tags.');
            this.loadVideos();
          }
        });
      }
    });
  }

  bulkDelete() {
    if (this.selectedVideos.size === 0) return;
    if (confirm(`Are you sure you want to delete ${this.selectedVideos.size} video(s)?`)) {
      const requests = Array.from(this.selectedVideos).map(id => this.api.deleteVideo(id));
      forkJoin(requests).subscribe({
        next: () => {
          this.selectedVideos = new Set();
          this.loadData();
        },
        error: () => {
          alert('Delete failed.');
          this.loadData();
        }
      });
    }
  }

  bulkUpdateTags() {
    if (this.selectedVideos.size === 0) return;
    
    const videosToUpdate = this.videos.filter(v => this.selectedVideos.has(v.id));
    
    const unionTagIds = new Set<string>();
    videosToUpdate.forEach(v => {
      (v.tags || []).forEach((t: any) => unionTagIds.add(t.id));
    });
    
    const currentTags = this.availableTags.filter(t => unionTagIds.has(t.id));

    const dialogRef = this.dialogService.open(UpdateTagsDialogComponent, {
      context: {
        videoId: 'bulk',
        currentTags: currentTags,
        availableTags: this.availableTags
      },
      contentClass: 'sm:max-w-sm'
    });

    dialogRef.closed$.subscribe(selectedTags => {
      if (!selectedTags) return; // User cancelled
      
      const newTagIds = selectedTags as string[];
      const requests: Observable<any>[] = [];
      
      videosToUpdate.forEach(video => {
        const videoTagIds = (video.tags || []).map(t => t.id);
        
        const tagsToAdd = newTagIds.filter(id => !videoTagIds.includes(id));
        const tagsToRemove = Array.from(unionTagIds).filter(id => !newTagIds.includes(id) && videoTagIds.includes(id));
        
        tagsToAdd.forEach(id => {
          requests.push(this.api.attachTag(video.id, id));
        });
        
        tagsToRemove.forEach(id => {
          requests.push(this.api.detachTag(video.id, id));
        });
      });
      
      if (requests.length > 0) {
        forkJoin(requests).subscribe({
          next: () => {
            this.selectedVideos = new Set();
            this.loadVideos();
          },
          error: () => {
            alert('Failed to update tags.');
            this.loadVideos();
          }
        });
      } else {
        this.selectedVideos = new Set();
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
    const m = Math.floor(seconds / 60);
    const s = Math.floor(seconds % 60);
    return `${m}:${s.toString().padStart(2, '0')}`;
  }
}
