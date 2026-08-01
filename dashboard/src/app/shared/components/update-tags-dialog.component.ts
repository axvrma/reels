import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';

import { HlmButtonImports } from '@spartan-ng/helm/button';
import { HlmLabelImports } from '@spartan-ng/helm/label';
import { HlmBadgeImports } from '@spartan-ng/helm/badge';
import { HlmIconImports } from '@spartan-ng/helm/icon';
import { BrnDialogRef, injectBrnDialogContext } from '@spartan-ng/brain/dialog';
import { provideIcons } from '@ng-icons/core';
import { lucideX } from '@ng-icons/lucide';

@Component({
  selector: 'app-update-tags-dialog',
  standalone: true,
  imports: [
    CommonModule, FormsModule, ReactiveFormsModule,
    HlmButtonImports, HlmLabelImports,
    HlmBadgeImports, HlmIconImports
  ],
  providers: [provideIcons({ lucideX })],
  template: `
    <div class="flex flex-col gap-4 p-6 w-full max-w-sm mx-auto bg-card text-card-foreground rounded-lg">
      <h2 class="text-lg font-semibold tracking-tight">Update Tags</h2>
      <div class="flex flex-col gap-4 pt-2">
        <div class="space-y-4">
          <label hlmLabel>Selected Tags</label>
          <div class="flex flex-wrap gap-2 min-h-[44px] p-2 border rounded-md bg-background">
            <span hlmBadge *ngFor="let id of selectedTagIds" variant="secondary" class="flex items-center gap-1 pl-2 pr-1 py-1">
              {{ getTagName(id) }}
              <button type="button" (click)="removeTag(id)" class="hover:bg-background rounded-full p-0.5 ml-1 transition-colors">
                <ng-icon hlm name="lucideX" class="h-3 w-3"></ng-icon>
              </button>
            </span>
            <span *ngIf="selectedTagIds.length === 0" class="text-sm text-muted-foreground italic p-1 flex items-center">No tags selected</span>
          </div>

          <div class="space-y-2">
            <label hlmLabel>Available Tags (Tap to add)</label>
            <div class="flex flex-wrap gap-2 max-h-[150px] overflow-y-auto p-2 border rounded-md bg-muted/10">
              <span hlmBadge *ngFor="let tag of availableToAdd" variant="outline" class="cursor-pointer hover:bg-secondary/50 transition-colors" (click)="addTag(tag.id)">
                + {{tag.name}}
              </span>
              <span *ngIf="availableToAdd.length === 0" class="text-sm text-muted-foreground italic p-1">No more tags to add</span>
            </div>
          </div>
        </div>
      </div>
      <div class="flex justify-end space-x-2 pt-4 mt-2 border-t">
        <button hlmBtn variant="ghost" (click)="closeDialog()">Cancel</button>
        <button hlmBtn (click)="onSave()">Save</button>
      </div>
    </div>
  `
})
export class UpdateTagsDialogComponent {
  private _dialogRef = inject(BrnDialogRef, { optional: true });
  public dialogContext = injectBrnDialogContext<{ videoId: string; currentTags: any[]; availableTags: any[] }>({ optional: true }) || { videoId: '', currentTags: [], availableTags: [] };
  
  selectedTagIds: string[] = [];

  constructor() {
    if (this.dialogContext.currentTags) {
      this.selectedTagIds = this.dialogContext.currentTags.map(t => t.id);
    }
  }

  get availableToAdd() {
    return this.dialogContext.availableTags.filter(t => !this.selectedTagIds.includes(t.id));
  }

  getTagName(id: string): string {
    const tag = this.dialogContext.availableTags.find(t => t.id === id);
    return tag ? tag.name : 'Unknown';
  }

  addTag(id: string) {
    if (id && !this.selectedTagIds.includes(id)) {
      this.selectedTagIds.push(id);
    }
  }

  removeTag(id: string) {
    this.selectedTagIds = this.selectedTagIds.filter(t => t !== id);
  }

  closeDialog() {
    if (this._dialogRef) {
      this._dialogRef.close();
    }
  }

  onSave() {
    if (this._dialogRef) {
      this._dialogRef.close(this.selectedTagIds);
    }
  }
}
