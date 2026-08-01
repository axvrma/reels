import { Component, inject } from '@angular/core';
import { FormBuilder, Validators, ReactiveFormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { AuthService } from '../services/auth.service';
import { CommonModule } from '@angular/common';

import { HlmCardImports } from '@spartan-ng/helm/card';
import { HlmInputImports } from '@spartan-ng/helm/input';
import { HlmButtonImports } from '@spartan-ng/helm/button';
import { HlmIconImports } from '@spartan-ng/helm/icon';
import { HlmLabelImports } from '@spartan-ng/helm/label';
import { HlmSpinnerImports } from '@spartan-ng/helm/spinner';
import { HlmFieldImports } from '@spartan-ng/helm/field';

import { provideIcons } from '@ng-icons/core';
import { lucideClapperboard, lucideMail, lucideLock, lucideEye, lucideEyeOff } from '@ng-icons/lucide';

@Component({
  selector: 'app-login-page',
  standalone: true,
  imports: [
    CommonModule, 
    ReactiveFormsModule,
    HlmCardImports,
    HlmInputImports,
    HlmButtonImports,
    HlmIconImports,
    HlmLabelImports,
    HlmSpinnerImports,
    HlmFieldImports
  ],
  providers: [
    provideIcons({ lucideClapperboard, lucideMail, lucideLock, lucideEye, lucideEyeOff })
  ],
  templateUrl: './login.page.html'
})
export class LoginPage {
  private fb = inject(FormBuilder);
  private auth = inject(AuthService);
  private router = inject(Router);

  loginForm = this.fb.group({
    email: ['', [Validators.required, Validators.email]],
    password: ['', Validators.required]
  });

  isLoading = false;
  hidePassword = true;
  errorMessage = '';

  onSubmit() {
    this.errorMessage = '';
    if (this.loginForm.valid) {
      this.isLoading = true;
      this.auth.login(this.loginForm.value).subscribe({
        next: () => {
          this.router.navigate(['/dashboard']);
        },
        error: (err) => {
          this.isLoading = false;
          this.errorMessage = err.error?.error?.message || 'Login failed';
        }
      });
    }
  }
}
