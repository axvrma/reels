import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule, ReactiveFormsModule, FormBuilder } from '@angular/forms';

import { HlmButtonImports } from '@spartan-ng/helm/button';
import { HlmLabelImports } from '@spartan-ng/helm/label';
import { BrnDialogRef, injectBrnDialogContext } from '@spartan-ng/brain/dialog';

@Component({
  selector: 'app-update-tags-dialog',
  standalone: true,
  imports: [
    CommonModule, FormsModule, ReactiveFormsModule,
    HlmButtonImports, HlmLabelImports
  ],
  template: `
    <div class="flex flex-col gap-4 p-6 w-full max-w-sm mx-auto bg-card text-card-foreground rounded-lg">
      <h2 class="text-lg font-semibold tracking-tight">Update Tags</h2>
      <form [formGroup]="form" class="flex flex-col gap-4 pt-2">
        <div class="space-y-2">
          <label hlmLabel>Tags</label>
          <select formControlName="tags" multiple class="flex min-h-[150px] w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2">
            <option *ngFor="let tag of dialogContext.availableTags" [value]="tag.id">
              {{tag.name}}
            </option>
          </select>
          <p class="text-xs text-muted-foreground">Hold Ctrl/Cmd to select multiple tags.</p>
        </div>
      </form>
      <div class="flex justify-end space-x-2 pt-4">
        <button hlmBtn variant="ghost" (click)="closeDialog()">Cancel</button>
        <button hlmBtn (click)="onSave()">Save</button>
      </div>
    </div>
  `
})
export class UpdateTagsDialogComponent {
  private fb = inject(FormBuilder);
  private _dialogRef = inject(BrnDialogRef, { optional: true });
  public dialogContext = injectBrnDialogContext<{ videoId: string; currentTags: any[]; availableTags: any[] }>({ optional: true }) || { videoId: '', currentTags: [], availableTags: [] };
  
  form = this.fb.group({
    tags: [[] as string[]]
  });

  constructor() {
    if (this.dialogContext.currentTags) {
      this.form.patchValue({
        tags: this.dialogContext.currentTags.map(t => t.id)
      });
    }
  }

  closeDialog() {
    if (this._dialogRef) {
      this._dialogRef.close();
    }
  }

  onSave() {
    if (this._dialogRef) {
      this._dialogRef.close(this.form.value.tags);
    }
  }
}
