import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule, ReactiveFormsModule, FormBuilder, Validators } from '@angular/forms';
import { MediaApiService } from '../services/media-api.service';

import { HlmCardImports } from '@spartan-ng/helm/card';
import { HlmButtonImports } from '@spartan-ng/helm/button';
import { HlmIconImports } from '@spartan-ng/helm/icon';
import { HlmInputImports } from '@spartan-ng/helm/input';
import { HlmLabelImports } from '@spartan-ng/helm/label';
import { NgScrollbarModule } from 'ngx-scrollbar';
import { HlmScrollAreaImports } from '@spartan-ng/helm/scroll-area';

import { provideIcons } from '@ng-icons/core';
import { lucidePlus, lucideTrash2, lucideX } from '@ng-icons/lucide';

@Component({
  selector: 'app-tags-page',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule,
    ReactiveFormsModule,
    HlmCardImports,
    HlmButtonImports,
    HlmIconImports,
    HlmInputImports,
    HlmLabelImports,
    HlmScrollAreaImports,
    NgScrollbarModule
  ],
  providers: [
    provideIcons({ lucidePlus, lucideTrash2, lucideX })
  ],
  templateUrl: './tags.page.html'
})
export class TagsPage implements OnInit {
  private api = inject(MediaApiService);
  private fb = inject(FormBuilder);
  private cdr = inject(ChangeDetectorRef);
  
  tags: any[] = [];
  
  isEditing = false;
  isCreating = false;
  editingId: string | null = null;
  
  tagForm = this.fb.group({
    name: ['', Validators.required],
    color: ['#22c55e']
  });

  ngOnInit() {
    this.loadData();
  }

  loadData() {
    this.api.getTags().subscribe(t => {
      this.tags = t;
      this.cdr.detectChanges();
    });
  }

  createNewTag() {
    this.isCreating = true;
    this.isEditing = false;
    this.editingId = null;
    this.tagForm.reset({ color: '#22c55e' });
  }

  onSubmit() {
    if (this.tagForm.valid) {
      if (this.isEditing && this.editingId) {
        this.api.updateTag(this.editingId, this.tagForm.value as any).subscribe({
          next: () => {
            this.cancelEdit();
            this.loadData();
          },
          error: (err) => this.handleError(err)
        });
      } else if (this.isCreating) {
        this.api.createTag(this.tagForm.value as any).subscribe({
          next: () => {
            this.cancelEdit();
            this.loadData();
          },
          error: (err) => this.handleError(err)
        });
      }
    }
  }

  editTag(tag: any) {
    this.isEditing = true;
    this.isCreating = false;
    this.editingId = tag.id;
    this.tagForm.patchValue({
      name: tag.name,
      color: tag.color
    });
  }

  cancelEdit() {
    this.isEditing = false;
    this.isCreating = false;
    this.editingId = null;
    this.tagForm.reset({ color: '#22c55e' });
  }

  deleteTag(event: Event, tag: any) {
    event.stopPropagation();

    if (window.confirm(`Are you sure you want to delete tag "${tag.name}"? This will remove it from all videos and categories.`)) {
      this.api.deleteTag(tag.id).subscribe({
        next: () => {
          if (this.editingId === tag.id) {
            this.cancelEdit();
          }
          this.loadData();
        },
        error: (err) => this.handleError(err)
      });
    }
  }

  handleError(err: any) {
    alert(err.error?.error?.message || 'Operation failed');
  }
}
