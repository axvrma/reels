import { Directive } from '@angular/core';
import { BrnTabsContentLazy } from '@spartan-ng/brain/tabs';

@Directive({
	standalone: true,
	selector: 'ng-template[hlmTabsContentLazy]',
	hostDirectives: [BrnTabsContentLazy],
})
export class HlmTabsContentLazy {}
