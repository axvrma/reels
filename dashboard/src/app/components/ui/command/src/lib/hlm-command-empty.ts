import { Directive } from '@angular/core';
import { classes } from '@spartan-ng/helm/utils';

@Directive({
	standalone: true,
	selector: '[hlmCommandEmpty]',
	host: {
		'data-slot': 'command-empty',
	},
})
export class HlmCommandEmpty {
	constructor() {
		classes(() => 'py-6 text-center text-sm');
	}
}
