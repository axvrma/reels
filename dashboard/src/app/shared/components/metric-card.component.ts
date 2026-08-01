import { Component, Input } from '@angular/core';
import { CommonModule } from '@angular/common';

import { HlmCardImports } from '@spartan-ng/helm/card';
import { HlmIconImports } from '@spartan-ng/helm/icon';
import { provideIcons } from '@ng-icons/core';
import { lucideVideo, lucideDatabase, lucideFolder, lucideTag } from '@ng-icons/lucide';

@Component({
  selector: 'app-metric-card',
  standalone: true,
  imports: [CommonModule, HlmCardImports, HlmIconImports],
  providers: [provideIcons({ lucideVideo, lucideDatabase, lucideFolder, lucideTag })],
  template: `
    <div hlmCard class="flex flex-col p-6 shadow-sm transition-colors hover:bg-muted/30 cursor-default">
      <div class="flex items-center justify-between pb-3">
        <span class="text-sm font-medium text-muted-foreground tracking-tight">{{ title }}</span>
        <div class="flex h-8 w-8 items-center justify-center rounded-md" [ngClass]="colorClass">
          <ng-icon hlm [name]="icon" class="h-4 w-4"></ng-icon>
        </div>
      </div>
      <div>
        <div class="text-2xl font-bold leading-none">{{ value }}</div>
        <p class="text-xs text-muted-foreground mt-1" *ngIf="subtitle">{{ subtitle }}</p>
      </div>
    </div>
  `
})
export class MetricCardComponent {
  @Input() title!: string;
  @Input() value!: string | number;
  @Input() subtitle?: string;
  @Input() icon!: string;
  @Input() colorClass: string = 'bg-primary/10 text-primary';
}
