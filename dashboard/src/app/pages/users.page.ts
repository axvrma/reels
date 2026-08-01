import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MediaApiService } from '../services/media-api.service';
import { DatePipe } from '@angular/common';
import { AuthService } from '../services/auth.service';

import { HlmCardImports } from '@spartan-ng/helm/card';
import { HlmButtonImports } from '@spartan-ng/helm/button';
import { HlmIconImports } from '@spartan-ng/helm/icon';
import { HlmTableImports } from '@spartan-ng/helm/table';
import { HlmBadgeImports } from '@spartan-ng/helm/badge';

import { provideIcons } from '@ng-icons/core';
import { lucideCheck, lucideCircleX, lucideKey, lucideTrash2 } from '@ng-icons/lucide';

@Component({
  selector: 'app-users-page',
  standalone: true,
  imports: [
    CommonModule,
    DatePipe,
    HlmCardImports,
    HlmButtonImports,
    HlmIconImports,
    HlmTableImports,
    HlmBadgeImports
  ],
  providers: [
    provideIcons({ lucideCheck, lucideCircleX, lucideKey, lucideTrash2 })
  ],
  templateUrl: './users.page.html'
})
export class UsersPage implements OnInit {
  private api = inject(MediaApiService);
  private auth = inject(AuthService);

  users: any[] = [];
  currentUser: any = null;

  ngOnInit() {
    this.auth.user$.subscribe(u => this.currentUser = u);
    this.loadUsers();
  }

  loadUsers() {
    this.api.getUsers().subscribe(users => {
      this.users = users;
    });
  }

  toggleUserStatus(user: any) {
    if (user.id === this.currentUser?.id) {
      alert('You cannot change your own status.');
      return;
    }

    const newStatus = !user.is_active;
    this.api.updateUserStatus(user.id, newStatus).subscribe({
      next: () => {
        user.is_active = newStatus;
      },
      error: (err) => {
        alert(err.error?.error?.message || 'Failed to update user status.');
      }
    });
  }

  deleteUser(user: any) {
    if (user.id === this.currentUser?.id) {
      alert('You cannot delete your own account.');
      return;
    }
    
    if (window.confirm(`Are you sure you want to delete ${user.email}? This cannot be undone.`)) {
      this.api.deleteUser(user.id).subscribe({
        next: () => {
          this.users = this.users.filter(u => u.id !== user.id);
        },
        error: (err) => {
          alert(err.error?.error?.message || 'Failed to delete user.');
        }
      });
    }
  }

  overridePassword(user: any) {
    const newPassword = window.prompt(`Enter new password for ${user.email} (min 6 characters):`);
    if (newPassword === null) return; // User cancelled
    
    if (newPassword.length < 6) {
      alert('Password must be at least 6 characters.');
      return;
    }
    
    if (window.confirm(`Are you sure you want to change the password for ${user.email}?`)) {
      this.api.updateUserPassword(user.id, newPassword).subscribe({
        next: () => {
          alert('Password updated successfully.');
        },
        error: (err) => {
          alert(err.error?.error?.message || 'Failed to update password.');
        }
      });
    }
  }
}
