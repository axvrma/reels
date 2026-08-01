import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule, ReactiveFormsModule, FormBuilder, Validators } from '@angular/forms';
import { MediaApiService } from '../services/media-api.service';

import { HlmCardImports } from '@spartan-ng/helm/card';
import { HlmButtonImports } from '@spartan-ng/helm/button';
import { HlmIconImports } from '@spartan-ng/helm/icon';
import { HlmInputImports } from '@spartan-ng/helm/input';
import { HlmLabelImports } from '@spartan-ng/helm/label';
import { HlmBadgeImports } from '@spartan-ng/helm/badge';
import { HlmSwitchImports } from '@spartan-ng/helm/switch';
import { HlmDropdownMenuImports } from '@spartan-ng/helm/dropdown-menu';
import { NgScrollbarModule } from 'ngx-scrollbar';

import { HlmScrollAreaImports } from '@spartan-ng/helm/scroll-area';

import { provideIcons } from '@ng-icons/core';
import { lucidePlus, lucideTrash2, lucideFolder, lucideTag, lucideX } from '@ng-icons/lucide';

@Component({
  selector: 'app-categories-page',
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
    HlmBadgeImports,
    HlmSwitchImports,
    HlmDropdownMenuImports,
    HlmScrollAreaImports,
    NgScrollbarModule
  ],
  providers: [
    provideIcons({ lucidePlus, lucideTrash2, lucideFolder, lucideTag, lucideX })
  ],
  templateUrl: './categories.page.html'
})
export class CategoriesPage implements OnInit {
  private api = inject(MediaApiService);
  private fb = inject(FormBuilder);
  private cdr = inject(ChangeDetectorRef);
  
  categories: any[] = [];
  availableTags: any[] = [];
  allVideos: any[] = [];
  
  isEditing = false;
  isCreating = false;
  editingId: string | null = null;
  currentTags: any[] = []; // Used to display tags for the category being edited
  
  categoryForm = this.fb.group({
    name: ['', Validators.required],
    slug: ['', Validators.required],
    color: ['#3f51b5'],
    sort_order: [0],
    is_active: [true]
  });

  ngOnInit() {
    this.loadData();
  }

  loadData() {
    this.api.getCategories(true).subscribe(res => {
      this.categories = res;
      this.cdr.detectChanges();
    });
    this.api.getTags().subscribe(t => {
      this.availableTags = t;
      this.cdr.detectChanges();
    });
    // Fetch videos to calculate video counts per category
    this.api.getVideos().subscribe(res => {
      this.allVideos = res.videos || [];
      this.cdr.detectChanges();
    });
  }

  getVideoCount(categoryId: string): number {
    return this.allVideos.filter(v => v.category && v.category.id === categoryId).length;
  }

  generateSlug() {
    if (this.isCreating) {
      const name = this.categoryForm.value.name || '';
      this.categoryForm.patchValue({
        slug: name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)+/g, '')
      });
    }
  }

  createNewCategory() {
    this.isCreating = true;
    this.isEditing = false;
    this.editingId = null;
    this.currentTags = [];
    this.categoryForm.reset({ color: '#3f51b5', sort_order: 0, is_active: true });
  }

  editCategory(cat: any) {
    this.isEditing = true;
    this.isCreating = false;
    this.editingId = cat.id;
    this.currentTags = cat.tags || [];
    
    this.categoryForm.patchValue({
      name: cat.name,
      slug: cat.slug,
      color: cat.color,
      sort_order: cat.sort_order,
      is_active: !!cat.is_active
    });
  }

  cancelEdit() {
    this.isEditing = false;
    this.isCreating = false;
    this.editingId = null;
    this.currentTags = [];
    this.categoryForm.reset();
  }

  onSubmit() {
    if (this.categoryForm.valid) {
      const payload = { ...this.categoryForm.value, is_active: this.categoryForm.value.is_active ? 1 : 0 };
      if (this.isEditing && this.editingId) {
        this.api.updateCategory(this.editingId, payload).subscribe({
          next: () => {
            this.cancelEdit();
            this.loadData();
          },
          error: (err) => this.handleError(err)
        });
      } else if (this.isCreating) {
        this.api.createCategory(payload).subscribe({
          next: () => {
            this.cancelEdit();
            this.loadData();
          },
          error: (err) => this.handleError(err)
        });
      }
    }
  }

  deleteCategory(event: Event, cat: any) {
    event.stopPropagation();
    const count = this.getVideoCount(cat.id);
    
    if (count > 0) {
      alert(`Cannot delete category "${cat.name}" because it has ${count} associated videos. Reassign videos first.`);
      return;
    }

    if (window.confirm(`Are you sure you want to delete category "${cat.name}"? This action cannot be undone.`)) {
      this.api.deleteCategory(cat.id).subscribe({
        next: () => {
          if (this.editingId === cat.id) {
            this.cancelEdit();
          }
          this.loadData();
        },
        error: (err) => this.handleError(err)
      });
    }
  }

  addTagToCategory(event: Event) {
    const tagId = (event.target as HTMLSelectElement).value;
    if (tagId && this.editingId) {
      this.api.assignTagToCategory(this.editingId, tagId).subscribe(() => {
        this.loadData();
        const tag = this.availableTags.find(t => t.id === tagId);
        if (tag && !this.currentTags.some(t => t.id === tagId)) {
          this.currentTags.push(tag);
        }
      });
    }
    // reset select
    (event.target as HTMLSelectElement).value = "";
  }

  removeTagFromCategory(tagId: string) {
    if (this.editingId) {
      this.api.removeTagFromCategory(this.editingId, tagId).subscribe(() => {
        this.loadData();
        this.currentTags = this.currentTags.filter(t => t.id !== tagId);
      });
    }
  }

  handleError(err: any) {
    alert(err.error?.error?.message || 'Operation failed');
  }
}
