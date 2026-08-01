import { Directive } from '@angular/core';
import { classes } from '@spartan-ng/helm/utils';

@Directive({
	standalone: true,
	selector: '[hlmPopoverDescription]',
	host: { 'data-slot': 'popover-description' },
})
export class HlmPopoverDescription {
	constructor() {
		classes(() => 'text-muted-foreground');
	}
}
