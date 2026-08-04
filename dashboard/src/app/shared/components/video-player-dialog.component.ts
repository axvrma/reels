import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { DomSanitizer, SafeResourceUrl } from '@angular/platform-browser';

import { HlmButtonImports } from '@spartan-ng/helm/button';
import { HlmIconImports } from '@spartan-ng/helm/icon';
import { BrnDialogRef, injectBrnDialogContext } from '@spartan-ng/brain/dialog';
import { provideIcons } from '@ng-icons/core';
import { lucideX } from '@ng-icons/lucide';

@Component({
  selector: 'app-video-player-dialog',
  standalone: true,
  imports: [CommonModule, HlmButtonImports, HlmIconImports],
  providers: [provideIcons({ lucideX })],
  template: `
    <div class="flex flex-col h-full bg-black text-white rounded-lg overflow-hidden">
      <div class="flex items-center justify-between p-4 bg-background/5 text-foreground z-10 absolute top-0 w-full bg-gradient-to-b from-black/80 to-transparent">
        <h2 class="text-lg font-semibold truncate text-white drop-shadow-md">{{ dialogContext.title || 'Video Player' }}</h2>
        <button hlmBtn variant="ghost" size="icon" (click)="closeDialog()" class="text-white hover:bg-white/20">
          <ng-icon hlm name="lucideX" class="h-5 w-5"></ng-icon>
        </button>
      </div>
      <div class="flex-1 flex items-center justify-center bg-black min-h-[50vh]">
        <video *ngIf="safeStreamUrl" [src]="safeStreamUrl" controls autoplay class="w-full h-full max-h-[85vh] object-contain"></video>
      </div>
    </div>
  `
})
export class VideoPlayerDialogComponent implements OnInit {
  private _dialogRef = inject(BrnDialogRef, { optional: true });
  public dialogContext = injectBrnDialogContext<{ title: string; streamUrl: string }>({ optional: true }) || { title: '', streamUrl: '' };
  private sanitizer = inject(DomSanitizer);
  public safeStreamUrl: SafeResourceUrl | null = null;

  ngOnInit() {
    if (this.dialogContext.streamUrl) {
      this.safeStreamUrl = this.sanitizer.bypassSecurityTrustResourceUrl(this.dialogContext.streamUrl);
    }
  }

  closeDialog() {
    if (this._dialogRef) {
      this._dialogRef.close();
    }
  }
}
