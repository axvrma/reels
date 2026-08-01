import { Component, inject } from '@angular/core';
import { RouterOutlet, RouterModule } from '@angular/router';
import { CommonModule } from '@angular/common';
import { AuthService } from './services/auth.service';
import { BreakpointObserver, Breakpoints } from '@angular/cdk/layout';
import { map, shareReplay } from 'rxjs/operators';
import { Observable } from 'rxjs';

import { HlmButtonImports } from '@spartan-ng/helm/button';
import { HlmIconImports } from '@spartan-ng/helm/icon';
import { HlmDropdownMenuImports } from '@spartan-ng/helm/dropdown-menu';

import { provideIcons } from '@ng-icons/core';
import { 
  lucideClapperboard, 
  lucideLayoutDashboard, 
  lucideFolder, 
  lucideTag, 
  lucideUsers, 
  lucideChartColumn, 
  lucideLogOut, 
  lucideMonitorSmartphone, 
  lucideMenu, 
  lucideCircleUser 
} from '@ng-icons/lucide';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [
    RouterOutlet, RouterModule, CommonModule,
    HlmButtonImports, HlmIconImports, HlmDropdownMenuImports, 
  ],
  providers: [
    provideIcons({
      lucideClapperboard,
      lucideLayoutDashboard,
      lucideFolder,
      lucideTag,
      lucideUsers,
      lucideChartColumn,
      lucideLogOut,
      lucideMonitorSmartphone,
      lucideMenu,
      lucideCircleUser
    })
  ],
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.scss']
})
export class AppComponent {
  auth = inject(AuthService);
  private breakpointObserver = inject(BreakpointObserver);

  isHandset$: Observable<boolean> = this.breakpointObserver.observe([
    Breakpoints.Handset,
    Breakpoints.TabletPortrait
  ]).pipe(
    map(result => result.matches),
    shareReplay()
  );

  isSidebarOpen = false;

  toggleSidebar() {
    this.isSidebarOpen = !this.isSidebarOpen;
  }

  logout() {
    this.auth.logout().subscribe();
  }

  logoutAll() {
    this.auth.logoutAll().subscribe();
  }
}
